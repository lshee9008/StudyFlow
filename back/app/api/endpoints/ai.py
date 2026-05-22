import asyncio
import json
import re
from typing import AsyncGenerator, List, Optional

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

import google.generativeai as genai

from app.core.config import settings
from app.core.redis_cache import cache_get, cache_set, make_key

router = APIRouter()

_CACHE_TTL = 3600
_SUMMARY_TOKENS = 12000
_SUMMARY_MAP_TOKENS = 2600
_SUMMARY_CONTINUE_TOKENS = 3600
_SUMMARY_CHUNK_CHARS = 3200
_SUMMARY_CHUNK_OVERLAP = 350
_SUMMARY_FORBIDDEN_MARKERS = (
    "원문 내용이 여기서 끝",
    "여기서 끝남",
    "이하 생략",
    "내용 없음",
    "추가 내용 없음",
    "본문 내용이 여기서 끝",
)


def _get_model() -> genai.GenerativeModel:
    if not settings.GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY is not configured")
    genai.configure(api_key=settings.GEMINI_API_KEY)
    return genai.GenerativeModel(settings.GEMINI_MODEL)


# ══════════════════════════════════════════════════════════
# 텍스트 유틸
# ══════════════════════════════════════════════════════════
def _meaningful(text: str) -> int:
    return len(re.sub(r'\s', '', text))


def _extract_text_structured(content: str) -> str:
    """JSON 블록 배열 → 마크다운 구조 보존 텍스트

    개선점 vs 기존 _extract_text:
    - h1/h2/h3 마크다운 헤딩 그대로 유지 → LLM이 문서 계층 파악 가능
    - 블록 간 \\n\\n 이중 개행 → 청킹 경계 기준점
    - quote, code, divider 포맷 보존
    """
    try:
        blocks = json.loads(content)
        parts = []
        for b in blocks:
            if not isinstance(b, dict):
                continue
            t = b.get("type", "text")
            c = (b.get("content") or b.get("controller", {}).get("text") or "").strip()
            if not c:
                continue
            if t == "h1":
                parts.append(f"# {c}")
            elif t == "h2":
                parts.append(f"## {c}")
            elif t == "h3":
                parts.append(f"### {c}")
            elif t == "bullet":
                parts.append(f"- {c}")
            elif t == "number":
                parts.append(f"1. {c}")
            elif t == "checkbox":
                parts.append(f"☐ {c}")
            elif t == "quote":
                parts.append(f"> {c}")
            elif t == "code":
                parts.append(f"```\n{c}\n```")
            elif t == "divider":
                parts.append("---")
            else:
                parts.append(c)
        return "\n\n".join(parts)   # ← \n\n: 청킹 경계 기준
    except Exception:
        return content


# 하위 호환성
_extract_text = _extract_text_structured


def _semantic_chunks(text: str, max_chars: int = 1500, overlap: int = 200) -> List[str]:
    """헤딩 우선 재귀 청킹 + overlap 컨텍스트 연결

    분할 우선순위: # > ## > ### > \\n\\n > \\n > ". "
    overlap: 이전 청크 끝 N자를 다음 청크 앞에 붙여 맥락 단절 방지
    """
    if len(text) <= max_chars:
        return [text]

    separators = ["\n# ", "\n## ", "\n### ", "\n\n", "\n", ". "]

    def _split(s: str, seps: List[str]) -> List[str]:
        if len(s) <= max_chars or not seps:
            return [s] if s.strip() else []

        sep = seps[0]
        raw_parts = re.split(f'({re.escape(sep)})', s)
        chunks, cur = [], ""
        i = 0
        while i < len(raw_parts):
            piece = raw_parts[i]
            if piece == sep:
                i += 1
                piece = sep + (raw_parts[i] if i < len(raw_parts) else "")
            if len(cur) + len(piece) <= max_chars:
                cur += piece
            else:
                if cur.strip():
                    chunks.append(cur.strip())
                if len(piece) <= max_chars:
                    cur = piece
                else:
                    sub = _split(piece, seps[1:])
                    chunks.extend(sub[:-1])
                    cur = sub[-1] if sub else ""
            i += 1
        if cur.strip():
            chunks.append(cur.strip())
        return chunks

    raw = _split(text, separators)
    if len(raw) <= 1:
        return raw

    # overlap: 이전 청크 끝을 단어 경계에서 잘라 붙임
    result = [raw[0]]
    for i in range(1, len(raw)):
        tail = raw[i - 1][-overlap:].strip()
        if tail and tail[-1] not in '.。\n':
            idx = max(tail.rfind(' '), tail.rfind('\n'))
            if idx > len(tail) // 2:
                tail = tail[idx + 1:]
        result.append(f"[앞 내용 연결]\n{tail}\n\n{raw[i]}" if tail else raw[i])
    return result


def _infer_node_description(text: str, label: str, group: str = "") -> str:
    label = (label or "").strip()
    if not label:
        return ""

    normalized = re.sub(r"\s+", "", label).lower()
    candidates = re.split(r"(?<=[.!?])\s+|\n+", text)
    for candidate in candidates:
        snippet = candidate.strip()
        if not snippet:
            continue
        if normalized in re.sub(r"\s+", "", snippet).lower():
            return snippet[:140]

    if group:
        return f"{group} 묶음에서 다루는 핵심 개념이다."
    return f"{label}와 관련된 핵심 개념이다."


def _normalize_quiz_items(raw_items, fallback_text: str, count: int = 8):
    sentence_pool = [
        s.strip()
        for s in re.split(r'(?<=[.!?])\s+|\n+', fallback_text)
        if len(s.strip()) > 12
    ]
    cleaned = []

    items = raw_items if isinstance(raw_items, list) else []
    for index, item in enumerate(items[:count]):
        if not isinstance(item, dict):
            continue
        question = str(item.get("question") or "").strip()
        options = item.get("options") if isinstance(item.get("options"), list) else []
        normalized_options = []
        for option in options:
            text = str(option or "").strip()
            if text:
                normalized_options.append(text)

        while len(normalized_options) < 4:
            fallback = sentence_pool[(index + len(normalized_options)) % len(sentence_pool)] if sentence_pool else "본문을 다시 확인해보세요."
            normalized_options.append(fallback[:80])

        normalized_options = normalized_options[:4]

        answer = item.get("answer", 0)
        try:
            answer = int(answer)
        except Exception:
            answer = 0
        answer = max(0, min(answer, len(normalized_options) - 1))

        explanation = str(item.get("explanation") or "").strip()
        if not explanation:
            explanation = sentence_pool[index % len(sentence_pool)] if sentence_pool else normalized_options[answer]

        if not question:
            if sentence_pool:
                question = f"다음 중 '{sentence_pool[index % len(sentence_pool)][:24]}'와 가장 관련 있는 설명은?"
            else:
                question = f"Q{index + 1}. 본문 내용과 가장 일치하는 설명은?"

        cleaned.append({
            "question": question,
            "options": normalized_options,
            "answer": answer,
            "explanation": explanation[:220],
        })

    terms = _extract_study_terms(fallback_text, limit=max(count + 4, 12))
    while len(cleaned) < count:
        index = len(cleaned)
        term = terms[index % len(terms)] if terms else f"핵심 개념 {index + 1}"
        desc = _infer_node_description(fallback_text, term)[:120]
        if not desc:
            desc = sentence_pool[index % len(sentence_pool)] if sentence_pool else "본문의 핵심 개념을 설명한다."
        cleaned.append({
            "question": f"Q{index + 1}. 본문에서 **{term}**에 대한 설명으로 가장 알맞은 것은?",
            "options": [
                desc,
                f"{term}은 본문과 직접 관련이 없는 개념이다.",
                f"{term}은 항상 생략해도 되는 부가 요소이다.",
                f"{term}은 다른 개념과 연결되지 않는 독립 항목이다.",
            ],
            "answer": 0,
            "explanation": desc[:220],
        })

    return cleaned


def _extract_study_terms(text: str, limit: int = 10):
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    heading_terms = [
        re.sub(r"^#+\s*", "", line).strip()
        for line in lines
        if line.startswith("#")
    ]
    bold_terms = re.findall(r"\*\*([^*\n]{2,50})\*\*", text)
    bullet_terms = [
        re.sub(r"^[-•\d.\s]+", "", line).split(":")[0].strip()
        for line in lines
        if re.match(r"^([-•]|\d+\.)\s+", line)
    ]

    terms = []
    for term in [*heading_terms, *bold_terms, *bullet_terms]:
        cleaned = re.sub(r"\s+", " ", term).strip(" -:：")
        if not cleaned or cleaned in terms or len(cleaned) > 60:
            continue
        terms.append(cleaned)
        if len(terms) >= limit:
            break

    if terms:
        return terms

    sentences = [
        sentence.strip()
        for sentence in re.split(r"(?<=[.!?。])\s+|\n+", text)
        if len(sentence.strip()) > 16
    ]
    for sentence in sentences[:limit]:
        terms.append(sentence[:32].strip(" -:："))
    return terms


def _fallback_analysis(text: str, title: str = "") -> str:
    clean = re.sub(r"\s+", " ", text).strip()
    terms = _extract_study_terms(clean, limit=6)
    primary = terms[0] if terms else clean[:40] or title or "이 문단"
    meaning = clean[:180] if clean else f"{primary}에 대한 핵심 설명입니다."
    related = ", ".join(terms[:3]) if terms else primary
    return (
        f"## 핵심 의미\n"
        f"- {meaning}\n\n"
        f"## 문맥 해석\n"
        f"- 이 문단은 **{primary}**를 중심으로 앞뒤 개념의 관계를 설명합니다.\n"
        f"- 관련 개념: **{related}**\n\n"
        f"## 왜 중요한가\n"
        f"- 정의만 외우기보다 역할, 작동 이유, 다른 구성 요소와의 연결을 함께 이해해야 합니다.\n\n"
        f"## 시험 포인트\n"
        f"- 정의, 역할, 원인과 결과를 구분해 설명할 수 있어야 합니다.\n"
        f"- 비슷한 용어와 비교해 오답 선택지를 걸러낼 수 있어야 합니다.\n\n"
        f"## 한 줄 정리\n"
        f"- **{primary}**는 본문 흐름에서 반드시 연결해 이해해야 할 핵심 항목입니다."
    )


def _fallback_memo(text: str, title: str = "") -> str:
    terms = _extract_study_terms(text, limit=8)
    if not terms:
        terms = [title or "핵심 개념", "정의", "역할", "구성 요소", "주의점"]

    rows = []
    for index, term in enumerate(terms[:8]):
        importance = "★★★" if index < 3 else ("★★" if index < 6 else "★")
        desc = _infer_node_description(text, term)[:90]
        rows.append(f"| **{term}** | {desc} | {importance} |")

    points = [
        f"- **{term}**: {_infer_node_description(text, term)[:120]}"
        for term in terms[:8]
    ]
    reviews = [
        f"- {term}의 정의와 역할을 한 문장으로 설명하기"
        for term in terms[:5]
    ]
    return (
        "## 핵심 개념\n"
        "| 개념 | 설명 | 중요도 |\n"
        "|------|------|--------|\n"
        + "\n".join(rows)
        + "\n\n## 암기 포인트\n"
        + "\n".join(points)
        + "\n\n## 빠른 복습\n"
        + "\n".join(reviews)
    )


def _fallback_quiz(text: str, count: int = 3):
    terms = _extract_study_terms(text, limit=max(4, count + 2))
    if not terms:
        terms = ["핵심 개념", "정의", "역할", "구성 요소"]
    items = []
    for index in range(max(1, count)):
        term = terms[index % len(terms)]
        desc = _infer_node_description(text, term)[:120]
        distractors = [
            f"{term}은 본문과 무관한 개념이다.",
            f"{term}은 항상 생략해도 되는 부가 요소이다.",
            f"{term}은 다른 구성 요소와 연결되지 않는다.",
        ]
        items.append({
            "question": f"Q{index + 1}. 본문에서 **{term}**에 대한 설명으로 가장 알맞은 것은?",
            "options": [desc, *distractors],
            "answer": 0,
            "explanation": desc,
        })
    return _normalize_quiz_items(items, text, count)


def _normalize_node_type(raw_type: str) -> str:
    token = (raw_type or "").strip().lower()
    if token in {"core", "root", "main"}:
        return "core"
    if token in {"branch", "topic", "section", "chapter"}:
        return "branch"
    return "detail"


def _normalize_graph_payload(nodes, edges, text: str):
    if not isinstance(nodes, list):
        nodes = []
    if not isinstance(edges, list):
        edges = []

    clean_nodes = []
    seen_ids = set()
    for i, node in enumerate(nodes):
        if not isinstance(node, dict):
            continue
        label = str(node.get("label") or "").strip()
        if not label:
            continue
        node_id = str(node.get("id") or f"node_{i}").strip() or f"node_{i}"
        if node_id in seen_ids:
            node_id = f"{node_id}_{i}"
        seen_ids.add(node_id)
        group = str(node.get("group") or "").strip()
        import re as _re
        def _strip_md(s: str) -> str:
            s = _re.sub(r'\*{1,3}', '', s)
            s = _re.sub(r'_{1,3}', '', s)
            s = _re.sub(r'^#+\s*', '', s, flags=_re.MULTILINE)
            return s.strip(' `')
        clean_nodes.append({
            "id": node_id,
            "label": _strip_md(label)[:80],
            "description": _strip_md(str(node.get("description") or "").strip())
            or _infer_node_description(text, label, group),
            "type": _normalize_node_type(str(node.get("type") or "detail")),
            "group": group[:40],
            "x": node.get("x"),
            "y": node.get("y"),
        })

    if not clean_nodes:
        return {"nodes": [], "edges": []}

    indegree = {n["id"]: 0 for n in clean_nodes}
    clean_edges = []
    valid_ids = {n["id"] for n in clean_nodes}
    seen_edges = set()

    for edge in edges:
        if not isinstance(edge, dict):
            continue
        source = str(edge.get("source") or "").strip()
        target = str(edge.get("target") or "").strip()
        if not source or not target or source == target:
            continue
        if source not in valid_ids or target not in valid_ids:
            continue
        key = (source, target)
        if key in seen_edges:
            continue
        seen_edges.add(key)
        indegree[target] = indegree.get(target, 0) + 1
        clean_edges.append({
            "source": source,
            "target": target,
            "label": str(edge.get("label") or "").strip()[:40],
        })

    root = next((n for n in clean_nodes if n["type"] == "core"), None)
    if root is None:
        root = next((n for n in clean_nodes if indegree.get(n["id"], 0) == 0), clean_nodes[0])
        root["type"] = "core"

    branches = [n for n in clean_nodes if n["id"] != root["id"] and n["type"] == "branch"]
    details = [n for n in clean_nodes if n["id"] != root["id"] and n["type"] == "detail"]

    if not branches and details:
        promoted = details[: min(4, len(details))]
        for node in promoted:
            node["type"] = "branch"
        branches = promoted
        details = [n for n in details if n not in promoted]

    connected_targets = {(e["source"], e["target"]) for e in clean_edges}
    incoming = {n["id"]: 0 for n in clean_nodes}
    for edge in clean_edges:
        incoming[edge["target"]] = incoming.get(edge["target"], 0) + 1
    if branches:
        for branch in branches:
            if incoming.get(branch["id"], 0) == 0 and (root["id"], branch["id"]) not in connected_targets:
                clean_edges.append({"source": root["id"], "target": branch["id"], "label": "핵심"})
                connected_targets.add((root["id"], branch["id"]))
                incoming[branch["id"]] = incoming.get(branch["id"], 0) + 1

    if details:
        branch_cycle = branches or [root]
        for idx, detail in enumerate(details):
            if incoming.get(detail["id"], 0) > 0:
                continue
            parent = branch_cycle[idx % len(branch_cycle)]
            if (parent["id"], detail["id"]) not in connected_targets:
                clean_edges.append({"source": parent["id"], "target": detail["id"], "label": "세부"})
                connected_targets.add((parent["id"], detail["id"]))
                incoming[detail["id"]] = incoming.get(detail["id"], 0) + 1

    ordered_nodes = [root]
    ordered_nodes.extend(sorted(
        [n for n in clean_nodes if n["id"] != root["id"] and n["type"] == "branch"],
        key=lambda n: (n["group"], n["label"]),
    ))
    ordered_nodes.extend(sorted(
        [n for n in clean_nodes if n["id"] != root["id"] and n["type"] == "detail"],
        key=lambda n: (n["group"], n["label"]),
    ))

    return {"nodes": ordered_nodes, "edges": clean_edges}


def _fallback_graph_from_text(text: str, title: str = ""):
    """LLM JSON 생성이 실패해도 화면에 의미 있는 기본 그래프를 제공한다."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    root_label = title.strip() or next(
        (
            re.sub(r"^#+\s*", "", line).strip()
            for line in lines
            if line.startswith("#")
        ),
        "핵심 요약",
    )

    heading_terms = [
        re.sub(r"^#+\s*", "", line).strip()
        for line in lines
        if line.startswith("#")
    ]
    bold_terms = re.findall(r"\*\*([^*\n]{2,40})\*\*", text)
    bullet_terms = [
        re.sub(r"^[-•\d.\s]+", "", line).split(":")[0].strip()
        for line in lines
        if re.match(r"^([-•]|\d+\.)\s+", line)
    ]

    terms = []
    for term in [*heading_terms, *bold_terms, *bullet_terms]:
        cleaned = re.sub(r"\s+", " ", term).strip(" -:：")
        if not cleaned or cleaned == root_label:
            continue
        if cleaned not in terms:
            terms.append(cleaned)
        if len(terms) >= 28:
            break

    if not terms:
        sentences = [
            sentence.strip()
            for sentence in re.split(r"(?<=[.!?。])\s+|\n+", text)
            if len(sentence.strip()) > 18
        ]
        for sentence in sentences[:8]:
            term = sentence[:24].strip(" -:：")
            if term and term not in terms:
                terms.append(term)

    nodes = [{
        "id": "root",
        "label": root_label[:40],
        "description": _infer_node_description(text, root_label),
        "type": "core",
        "group": "",
    }]
    edges = []

    branch_count = min(6, max(1, len(terms)))
    last_by_branch = {branch: f"n{branch}" for branch in range(1, branch_count + 1)}
    for index, term in enumerate(terms[:28], start=1):
        node_type = "branch" if index <= branch_count else "detail"
        if node_type == "branch":
            parent = "root"
        else:
            branch_no = ((index - branch_count - 1) % branch_count) + 1
            parent = last_by_branch.get(branch_no, f"n{branch_no}")
        node_id = f"n{index}"
        nodes.append({
            "id": node_id,
            "label": term[:40],
            "description": _infer_node_description(text, term),
            "type": node_type,
            "group": "",
        })
        edges.append({
            "source": parent,
            "target": node_id,
            "label": "핵심" if node_type == "branch" else "세부",
        })
        if node_type == "detail":
            branch_no = ((index - branch_count - 1) % branch_count) + 1
            chain_pos = (index - branch_count - 1) // branch_count
            if chain_pos < 4:
                last_by_branch[branch_no] = node_id

    return _normalize_graph_payload(nodes, edges, text)


# ══════════════════════════════════════════════════════════
# LLM 호출 — 비스트리밍 (Redis 캐시 포함)
# ══════════════════════════════════════════════════════════
async def _llm(prompt: str, temp: float = 0.2, tokens: int = 1500) -> str:
    key = make_key(prompt, temp, tokens, prefix="sf:llm")

    cached = await cache_get(key)
    if cached is not None:
        return cached

    model = _get_model()
    cfg = genai.types.GenerationConfig(temperature=temp, max_output_tokens=tokens)
    response = await model.generate_content_async(prompt, generation_config=cfg)
    result = response.text.strip() if response.text else ""

    await cache_set(key, result, ttl=_CACHE_TTL)
    return result


# ══════════════════════════════════════════════════════════
# LLM 스트리밍 제너레이터
# ══════════════════════════════════════════════════════════
async def _llm_stream(prompt: str, temp: float = 0.2, tokens: int = 2000) -> AsyncGenerator[str, None]:
    """Gemini stream=True → 토큰 단위 async generator

    Gemini 2.5 Flash는 내부적으로 청크를 버퍼링할 수 있으므로
    각 청크 후 asyncio.sleep(0)으로 이벤트 루프에 제어권을 돌려줌
    """
    model = _get_model()
    cfg = genai.types.GenerationConfig(temperature=temp, max_output_tokens=tokens)
    response = await model.generate_content_async(prompt, generation_config=cfg, stream=True)
    async for chunk in response:
        if chunk.text:
            yield chunk.text
            await asyncio.sleep(0)  # 이벤트 루프 양보 → SSE 즉시 플러시


# ══════════════════════════════════════════════════════════
# 프롬프트 빌더
# ══════════════════════════════════════════════════════════
def _structure_hint(text: str) -> str:
    h1s = [line[2:].strip() for line in text.split('\n') if line.startswith('# ')]
    return f"문서 주제: {' / '.join(h1s[:4])}\n" if h1s else ""


def _build_reduce_prompt(title: str, tags: str, text: str, user_instruction: str = "") -> str:
    """단일 청크 — 직접 요약 프롬프트"""
    hint = _structure_hint(text)
    if user_instruction:
        return (
            f"사용자 지시: {user_instruction}\n"
            f"{hint}제목: {title}  태그: {tags}\n\n"
            f"[본문]\n{text}\n\n"
            "위 지시에 따르되, 원문 문단의 순서와 흐름을 최대한 유지해 정리하세요.\n"
            "삭제식 요약이 아니라 문단별 내용을 읽기 좋은 학습 노트로 다듬는 방식입니다.\n"
            "주요 개념, 정의, 원리, 예시, 비교, 암기 포인트를 빠뜨리지 마세요.\n"
            "본문에 없는 내용 추가 금지. 마크다운 제목과 불릿으로 읽기 쉽게 작성하세요.\n"
            "\"원문 내용이 여기서 끝남\", \"이하 생략\" 같은 메타 문구는 절대 쓰지 마세요."
        )
    return (
        f"당신은 강의 내용을 문단 흐름 그대로 살려 정리하는 시험 대비 학습 노트 전문가입니다.\n"
        f"{hint}제목: {title}  태그: {tags}\n\n"
        f"[본문]\n{text}\n\n"
        "원문 순서를 유지하며 충분히 자세한 학습 노트로 정리하세요.\n\n"
        "## 문단 흐름 정리\n"
        "- 원문에 나온 순서대로 단원/문단을 따라가며 정리\n"
        "- 각 문단의 핵심 주장, 정의, 이유, 예시를 함께 보존\n\n"
        "## 핵심 개념과 세부 설명\n"
        "- **개념명**: 정의, 역할, 원리, 본문 근거, 관련 예시\n\n"
        "## 시험 포인트\n"
        "- 헷갈리기 쉬운 부분, 암기해야 할 용어, 출제 가능 포인트\n\n"
        "## 핵심 정리\n"
        "- 반드시 기억할 5~8가지 포인트\n\n"
        "작성 규칙:\n"
        "- 본문에 있는 내용만 사용 (창작 금지)\n"
        "- 원문에 나온 중요한 항목은 생략하지 말기\n"
        "- 원문 단락의 진행 순서를 바꾸지 말기\n"
        "- 과도하게 줄이지 말고 원문 정보량의 60% 이상을 보존\n"
        "- 개념명·용어는 **굵게** 표시\n"
        "- 빈 섹션 출력 금지\n"
        "- 이모티콘·장식 기호 금지\n"
        "- ## 계층 구조를 적극 활용\n"
        "- \"원문 내용이 여기서 끝남\", \"이하 생략\", \"추가 내용 없음\" 같은 메타 문구 금지\n"
        "- 마지막 문장까지 완결된 형태로 끝내기"
    )


def _build_map_prompt(chunk: str, index: int, total: int) -> str:
    """청크 압축 프롬프트 — Map 단계"""
    return (
        f"다음 학습 내용은 전체 문서의 {index + 1}/{total}번째 구간입니다.\n"
        "이 구간을 압축해 버리지 말고, 원문 문단 순서와 설명 흐름을 유지한 섹션 노트로 정리하세요.\n\n"
        "규칙:\n"
        "- 원문에 나온 순서대로 정리\n"
        "- 개념명, 정의, 원리, 구성 요소, 예시, 비교, 암기 포인트를 포함\n"
        "- 불필요한 반복만 줄이고 세부 설명은 보존\n"
        "- 본문에 없는 내용 추가 금지\n"
        "- 적절한 소제목과 bullet 사용\n"
        "- 너무 짧게 쓰지 말고 이 구간 정보량의 60% 이상 유지\n\n"
        "- \"원문 내용이 여기서 끝남\", \"이하 생략\", \"추가 내용 없음\" 같은 메타 문구 금지\n\n"
        f"[내용]\n{chunk}\n\n"
        "섹션 노트:"
    )


def _build_merge_prompt(title: str, tags: str, summaries: List[str], user_instruction: str = "") -> str:
    """청크 요약 통합 프롬프트 — Reduce 단계"""
    combined = "\n\n".join(f"### 섹션 {i + 1}\n{s}" for i, s in enumerate(summaries))
    if user_instruction:
        return (
            f"사용자 지시: {user_instruction}\n"
            f"제목: {title}  태그: {tags}\n\n"
            f"[섹션별 분석]\n{combined}\n\n"
            "위 지시에 따라 하나의 완성된 시험 대비 노트로 통합하세요.\n"
            "섹션 순서를 유지하고, 중복만 줄이되 중요한 개념, 정의, 원리, 예시, 비교, 암기 포인트는 생략하지 마세요.\n"
            "\"원문 내용이 여기서 끝남\", \"이하 생략\" 같은 메타 문구는 절대 쓰지 마세요."
        )
    return (
        f"당신은 강의 전체 흐름을 보존해 하나의 노트로 엮는 시험 대비 학습 노트 전문가입니다.\n"
        f"제목: {title}  태그: {tags}\n\n"
        f"[섹션별 노트]\n{combined}\n\n"
        "위 섹션들을 순서대로 이어 하나의 완성된 학습 노트로 통합하세요.\n\n"
        "## 문단 흐름 정리\n"
        "- 섹션 1부터 마지막 섹션까지 원래 순서대로 설명\n"
        "- 각 단원의 정의, 배경, 과정, 예시, 비교를 자연스럽게 연결\n\n"
        "## 핵심 개념과 세부 설명\n"
        "- **개념명**: 정의, 역할, 원리, 관련 개념, 본문 근거\n\n"
        "## 시험 포인트\n"
        "- 헷갈리기 쉬운 부분, 암기 포인트, 출제 가능 포인트\n\n"
        "## 핵심 정리\n"
        "- 전체 내용에서 가장 중요한 5~8가지\n\n"
        "작성 규칙:\n"
        "- 섹션 순서를 반드시 유지\n"
        "- 섹션 간 중복만 제거 후 통합\n"
        "- 중요한 항목은 생략하지 말기\n"
        "- 짧게 압축하지 말고 원문 흐름과 세부 설명을 살리기\n"
        "- 본문에 없는 내용 추가 금지\n"
        "- 개념명은 **굵게**\n"
        "- 자연스러운 문단 흐름 유지\n"
        "- 이모티콘·장식 기호 금지\n"
        "- \"원문 내용이 여기서 끝남\", \"이하 생략\", \"추가 내용 없음\" 같은 메타 문구 금지\n"
        "- 마지막 섹션까지 완결된 형태로 끝내기"
    )


def _clean_summary_output(text: str) -> str:
    """Remove model meta notes that make the summary look truncated."""
    if not text:
        return ""
    lines = []
    for line in text.splitlines():
        if any(marker in line for marker in _SUMMARY_FORBIDDEN_MARKERS):
            continue
        lines.append(line.rstrip())
    cleaned = "\n".join(lines).strip()
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned


def _looks_incomplete(text: str) -> bool:
    if _meaningful(text) < 20:
        return True
    stripped = text.rstrip()
    tail = stripped[-120:]
    if re.search(r"(^|\n)\s*(?:[-*]|\d+[.)])\s*$", tail):
        return True
    if re.search(r"(?:[:(（,，·/]|및|와|과|또는|그리고|으로|로|를|을|버스를)\s*$", tail):
        return True
    return not re.search(r"(다\.|요\.|[.!?)]|```)$", stripped)


def _summary_needs_continuation(text: str) -> bool:
    if _meaningful(text) < 80:
        return False
    if any(marker in text for marker in _SUMMARY_FORBIDDEN_MARKERS):
        return True
    return _looks_incomplete(text)


def _build_continue_prompt(title: str, tags: str, source: str, current: str) -> str:
    return (
        "아래 학습 노트 요약이 중간에 끊겼거나 일부 항목이 덜 마감되었습니다.\n"
        "기존 내용을 반복하지 말고, 원문 흐름을 따라 남은 핵심 내용을 이어서 완성하세요.\n\n"
        f"제목: {title}  태그: {tags}\n\n"
        f"[원문]\n{source[:10000]}\n\n"
        f"[현재까지 작성된 요약]\n{current[-5000:]}\n\n"
        "이어쓰기 규칙:\n"
        "- 현재 요약의 마지막 완성 지점 다음부터 자연스럽게 이어쓰기\n"
        "- 원문에 있는 정의, 구성 요소, 예시, 비교, 시험 포인트를 빠뜨리지 않기\n"
        "- 본문에 없는 내용 추가 금지\n"
        "- 기존 문단을 반복하지 않기\n"
        "- \"원문 내용이 여기서 끝남\", \"이하 생략\", \"추가 내용 없음\" 같은 메타 문구 금지\n"
        "- 마지막에는 필요한 경우 ## 핵심 정리로 완결하기\n\n"
        "이어지는 내용:"
    )


async def _complete_summary_if_needed(title: str, tags: str, source: str, current: str) -> str:
    force_continue = any(marker in current for marker in _SUMMARY_FORBIDDEN_MARKERS)
    completed = _clean_summary_output(current)
    for _ in range(2):
        if not force_continue and not _summary_needs_continuation(completed):
            break
        force_continue = False
        extra = await _llm(
            _build_continue_prompt(title, tags, source, completed),
            temp=0.15,
            tokens=_SUMMARY_CONTINUE_TOKENS,
        )
        extra = _clean_summary_output(extra)
        if _meaningful(extra) < 20:
            break
        completed = f"{completed.rstrip()}\n\n{extra.strip()}".strip()
    return _clean_summary_output(completed)


# ══════════════════════════════════════════════════════════
# /summarize  — 비스트리밍 (폴백 / 캐시 활용)
# ══════════════════════════════════════════════════════════
class SumReq(BaseModel):
    content: str
    tags: str = ""
    title: str = ""
    custom_prompt: Optional[str] = None
    server_prompt: Optional[str] = None


@router.post("/summarize")
async def summarize(req: SumReq):
    raw = _extract_text_structured(req.content.strip())
    if _meaningful(raw) < 20:
        return {"summary": ""}

    user_instruction = req.custom_prompt or req.server_prompt or ""
    chunks = _semantic_chunks(
        raw,
        max_chars=_SUMMARY_CHUNK_CHARS,
        overlap=_SUMMARY_CHUNK_OVERLAP,
    )

    try:
        if len(chunks) == 1:
            prompt = _build_reduce_prompt(req.title, req.tags, raw, user_instruction)
            result = await _llm(prompt, temp=0.2, tokens=_SUMMARY_TOKENS)
        else:
            map_results = await asyncio.gather(*[
                _llm(_build_map_prompt(c, i, len(chunks)), temp=0.15, tokens=_SUMMARY_MAP_TOKENS)
                for i, c in enumerate(chunks)
            ])
            valid = [r for r in map_results if _meaningful(r) > 10]
            if not valid:
                return {"summary": ""}
            merge_prompt = _build_merge_prompt(req.title, req.tags, valid, user_instruction)
            result = await _llm(merge_prompt, temp=0.2, tokens=_SUMMARY_TOKENS)

        result = await _complete_summary_if_needed(req.title, req.tags, raw, result)
        return {"summary": result if _meaningful(result) > 10 else ""}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /summarize-stream  — SSE 스트리밍 (메인)
# ══════════════════════════════════════════════════════════
@router.post("/summarize-stream")
async def summarize_stream(req: SumReq):
    """Server-Sent Events 스트리밍 요약

    이벤트 형식:
      data: {"type": "progress", "message": "..."}  진행 상태
      data: {"type": "token",    "text": "..."}      실시간 토큰
      data: {"type": "done",     "text": "..."}      완성 전문
      data: {"type": "error",    "message": "..."}   오류
      data: [DONE]                                    스트림 종료
    """
    def _sse(obj: dict) -> str:
        return f"data: {json.dumps(obj, ensure_ascii=False)}\n\n"

    async def generate():
        raw = _extract_text_structured(req.content.strip())
        if _meaningful(raw) < 20:
            yield _sse({"type": "done", "text": ""})
            yield "data: [DONE]\n\n"
            return

        user_instruction = req.custom_prompt or req.server_prompt or ""
        chunks = _semantic_chunks(
            raw,
            max_chars=_SUMMARY_CHUNK_CHARS,
            overlap=_SUMMARY_CHUNK_OVERLAP,
        )

        try:
            if len(chunks) == 1:
                yield _sse({"type": "progress", "message": "요약 생성 중..."})
                reduce_prompt = _build_reduce_prompt(req.title, req.tags, raw, user_instruction)
            else:
                yield _sse({"type": "progress", "message": f"{len(chunks)}개 섹션 분석 중..."})

                # Map: 병렬 청크 정리. 긴 문서에서도 SSE가 조용히 끊기지 않도록 진행 이벤트 유지.
                map_task = asyncio.gather(*[
                    _llm(_build_map_prompt(c, i, len(chunks)), temp=0.15, tokens=_SUMMARY_MAP_TOKENS)
                    for i, c in enumerate(chunks)
                ])
                while not map_task.done():
                    yield _sse({"type": "progress", "message": "문단 흐름을 따라 정리 중..."})
                    await asyncio.sleep(8)
                map_results = await map_task
                valid = [r for r in map_results if _meaningful(r) > 10]

                if not valid:
                    yield _sse({"type": "done", "text": ""})
                    yield "data: [DONE]\n\n"
                    return

                yield _sse({"type": "progress", "message": "통합 요약 생성 중..."})
                reduce_prompt = _build_merge_prompt(req.title, req.tags, valid, user_instruction)

            # Reduce: 스트리밍 출력
            full_text = ""
            async for token in _llm_stream(reduce_prompt, temp=0.2, tokens=_SUMMARY_TOKENS):
                full_text += token
                yield _sse({"type": "token", "text": token})

            cleaned_text = _clean_summary_output(full_text)
            completed_text = await _complete_summary_if_needed(req.title, req.tags, raw, cleaned_text)
            if completed_text != cleaned_text:
                continuation = completed_text[len(cleaned_text):].strip()
                if continuation:
                    yield _sse({"type": "progress", "message": "끊긴 부분을 이어서 마감 중..."})
                    yield _sse({"type": "token", "text": f"\n\n{continuation}"})

            yield _sse({"type": "done", "text": completed_text.strip()})
            yield "data: [DONE]\n\n"

        except Exception as e:
            yield _sse({"type": "error", "message": str(e)})

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


# ══════════════════════════════════════════════════════════
# /analyze-block  — 포커스 블록 분석
# ══════════════════════════════════════════════════════════
class BlockReq(BaseModel):
    text: str
    context_title: str = ""


@router.post("/analyze-block")
async def analyze_block(req: BlockReq):
    if _meaningful(req.text) < 15:
        return {"analysis": ""}
    title_hint = f"제목: {req.context_title}\n" if req.context_title else ""
    p = (
        f"당신은 대학원 수준의 학습 튜터입니다. 학생이 작성한 문단을 깊이 분석해주세요.\n"
        f"{title_hint}"
        f"분석할 문단:\n{req.text[:2000]}\n\n"
        "본문에 있는 내용만 사용하고 창작은 절대 금지합니다.\n\n"
        "아래 형식으로 정확히 출력하세요:\n\n"
        "## 핵심 의미\n"
        "- 이 문단의 핵심 주장을 3~5문장으로 명확하게 설명\n"
        "- 정의, 원리, 역할을 포함해 설명\n\n"
        "## 문맥 해석\n"
        "- 앞뒤 개념과 어떻게 연결되는지 설명\n"
        "- 비유나 예시가 있으면 무엇을 위한 것인지 해석\n"
        "- 왜 이 내용이 중요한지 학습 관점에서 설명\n\n"
        "## 연결 개념 맵\n"
        "- **개념 A** → 어떤 연관이 있는지\n"
        "- **개념 B** → 어떤 연관이 있는지\n"
        "(본문에 등장하는 연관 개념 3~5개 기술)\n\n"
        "## 오개념 주의\n"
        "- 학생들이 이 개념에서 자주 실수하는 점 2~3가지\n"
        "- 헷갈리기 쉬운 유사 개념과의 차이\n\n"
        "## 예상 시험 문제\n"
        "**Q1.** (질문)\n**정답:** (답)\n**해설:** (짧은 해설)\n\n"
        "**Q2.** (질문)\n**정답:** (답)\n**해설:** (짧은 해설)\n\n"
        "**Q3.** (질문)\n**정답:** (답)\n**해설:** (짧은 해설)\n\n"
        "## 한 줄 정리\n"
        "- 이 문단에서 반드시 기억해야 할 결론 1문장\n\n"
        "규칙:\n"
        "- 본문 기반 · 최소 600자 이상\n"
        "- 개념명 **굵게**\n"
        "- 이모티콘 금지\n"
        "- 빈 항목 금지\n"
        "- 마지막 문장 완결"
    )
    try:
        result = await _llm(p, temp=0.15, tokens=2400)
        if _meaningful(result) < 280 or _looks_incomplete(result):
            result = _fallback_analysis(req.text, req.context_title)
        return {"analysis": result}
    except Exception:
        return {"analysis": _fallback_analysis(req.text, req.context_title)}


# ══════════════════════════════════════════════════════════
# /memo  — 핵심 암기 노트
# ══════════════════════════════════════════════════════════
class MemoReq(BaseModel):
    content: str
    title: str = ""


@router.post("/memo")
async def memo(req: MemoReq):
    text = _extract_text_structured(req.content.strip())
    if _meaningful(text) < 20:
        return {"memo": ""}
    p = (
        f"제목: {req.title}\n"
        f"본문:\n{text[:8000]}\n\n"
        "시험 직전에 볼 수 있는 핵심 암기 노트를 작성하세요. 본문에 있는 내용만 사용하고 창작은 금지합니다.\n\n"
        "## 핵심 개념\n"
        "아래 표를 완성하세요 (반드시 헤더와 구분선 포함, 최소 8행 이상):\n\n"
        "| 개념 | 설명 | 중요도 |\n"
        "|------|------|--------|\n"
        "| 개념명 | 한 줄 정의 | ★★★ |\n\n"
        "## 암기 포인트\n"
        "- **개념명**: 헷갈리기 쉬운 점과 기억할 내용을 함께 정리 (최소 8개)\n\n"
        "## 연상 기법\n"
        "- 각 핵심 개념을 외우기 위한 기억 장치, 연상어, 약어 또는 이야기 구조로 정리\n"
        "- 형식: **개념명** → 연상 방법\n"
        "(본문에 등장하는 개념 중 암기가 필요한 것들 기준, 3~5개)\n\n"
        "## 자주 나오는 오답\n"
        "- 이 주제에서 학생들이 자주 틀리는 개념 또는 표현 2~4가지\n"
        "- 형식: ❌ 틀린 이해 → ✅ 올바른 이해\n\n"
        "## 스스로 점검\n"
        "다음 질문에 답할 수 있는지 확인하세요 (정답은 본문에 있음):\n"
        "1. (질문)\n"
        "2. (질문)\n"
        "3. (질문)\n"
        "4. (질문)\n"
        "5. (질문)\n\n"
        "작성 규칙:\n"
        "- 표는 반드시 완결된 형태로 출력 (잘리지 않게)\n"
        "- 개념명은 **굵게**\n"
        "- 중요도: ★★★(매우중요) / ★★(중요) / ★(보통)\n"
        "- 이모티콘 금지 (❌✅ 기호는 허용)\n"
        "- 본문에 없는 내용 추가 금지"
    )
    try:
        r = await _llm(p, temp=0.15, tokens=4200)
        table_rows = len(re.findall(r"^\|\s*\*\*?.+?\|.+?\|.+?\|", r, re.MULTILINE))
        if _meaningful(r) < 240 or table_rows < 6 or _looks_incomplete(r):
            r = _fallback_memo(text, req.title)
        return {"memo": r}
    except Exception as e:
        fallback = _fallback_memo(text, req.title)
        if _meaningful(fallback) > 20:
            return {"memo": fallback}
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /quiz  — 퀴즈 생성
# ══════════════════════════════════════════════════════════
class QuizReq(BaseModel):
    content: str
    count: int = 8


@router.post("/quiz")
async def quiz(req: QuizReq):
    text = _extract_text_structured(req.content.strip())
    if _meaningful(text) < 30:
        return {"quiz": []}
    count = max(6, min(req.count, 12))
    mc_count = max(4, count - 2)
    p = (
        f"본문:\n{text[:8000]}\n\n"
        f"위 본문으로 총 {count}문제를 만드세요 (객관식 {mc_count}개 + OX문제 1개 + 빈칸채우기 1개).\n\n"
        "중요: JSON 배열만 출력하세요. 그 외 텍스트 절대 금지.\n\n"
        "형식:\n"
        "[{\n"
        "  \"type\": \"mc\",\n"
        "  \"question\": \"질문\",\n"
        "  \"options\": [\"A\", \"B\", \"C\", \"D\"],\n"
        "  \"answer\": 0,\n"
        "  \"explanation\": \"해설\"\n"
        "},\n"
        "{\n"
        "  \"type\": \"ox\",\n"
        "  \"question\": \"OX로 답할 수 있는 서술 문장\",\n"
        "  \"options\": [\"O\", \"X\"],\n"
        "  \"answer\": 0,\n"
        "  \"explanation\": \"해설\"\n"
        "},\n"
        "{\n"
        "  \"type\": \"fill\",\n"
        "  \"question\": \"___에 들어갈 말로 올바른 것은?\",\n"
        "  \"options\": [\"선택지A\", \"선택지B\", \"선택지C\", \"선택지D\"],\n"
        "  \"answer\": 0,\n"
        "  \"explanation\": \"해설\"\n"
        "}]\n\n"
        "규칙:\n"
        f"- 정확히 {count}개 문제 (mc {mc_count}개, ox 1개, fill 1개)\n"
        "- type 필드는 반드시 \"mc\", \"ox\", \"fill\" 중 하나\n"
        "- options: 정확히 4개 문자열 배열\n"
        "- answer: 정답 인덱스 정수 (0, 1, 2, 3 중 하나)\n"
        "- explanation: 정답 근거 (본문 기반, 2~4문장)\n"
        "- 쉬운 문제만 만들지 말고 정의, 역할, 개념 비교, 원인/결과, 예시 해석을 섞기\n"
        "- 본문에 없는 내용으로 문제 생성 금지\n"
        "- JSON이 끊기지 않도록 완결된 배열로 끝내기"
    )
    try:
        raw = await _llm(p, temp=0.1, tokens=6000)
        # 코드블록 제거
        raw = raw.replace("```json", "").replace("```", "").strip()
        # JSON 배열 추출 — 가장 바깥 [ ] 쌍 찾기
        s, e = raw.find("["), raw.rfind("]")
        if s != -1 and e != -1 and e > s:
            chunk = raw[s:e + 1]
            try:
                parsed = json.loads(chunk)
            except json.JSONDecodeError:
                # 잘린 JSON 복구 시도: 마지막 완성된 객체까지만 사용
                last_obj_end = chunk.rfind("},")
                if last_obj_end > 0:
                    try:
                        repaired = chunk[:last_obj_end + 1] + "]"
                        parsed = json.loads(repaired)
                    except Exception:
                        return {"quiz": _fallback_quiz(text, count)}
                else:
                    return {"quiz": _fallback_quiz(text, count)}
            normalized = _normalize_quiz_items(parsed, text, count)
            return {"quiz": normalized if normalized else _fallback_quiz(text, count)}

        obj_start, obj_end = raw.find("{"), raw.rfind("}")
        if obj_start != -1 and obj_end != -1 and obj_end > obj_start:
            parsed_obj = json.loads(raw[obj_start:obj_end + 1])
            raw_quiz = parsed_obj.get("quiz") or parsed_obj.get("questions") or []
            normalized = _normalize_quiz_items(raw_quiz, text, count)
            return {"quiz": normalized if normalized else _fallback_quiz(text, count)}

        return {"quiz": _fallback_quiz(text, count)}
    except Exception:
        return {"quiz": _fallback_quiz(text, max(6, min(req.count, 12)))}


# ══════════════════════════════════════════════════════════
# /ask  — RAG + 웹 검색
# ══════════════════════════════════════════════════════════
class AskReq(BaseModel):
    query: str
    project_id: str
    use_web_search: bool = True


@router.post("/ask")
async def ask(req: AskReq):
    if not req.query.strip():
        raise HTTPException(400, "empty")
    ctx, src = "", "일반 지식"
    try:
        from app.core.vector_store import get_vector_store
        vs = get_vector_store()
        docs = vs.similarity_search_with_score(req.query, k=4,
                                               filter={"project_id": req.project_id})
        rel = [(d, s) for d, s in docs if s < 0.6]
        if rel:
            ctx = "\n\n".join([d.page_content for d, _ in rel])
            src = "내 노트"
    except Exception:
        pass
    if not ctx and req.use_web_search:
        try:
            from app.core.web_search import get_web_search_tool
            r = get_web_search_tool().invoke(req.query)
            ctx = "\n".join([x['content'] for x in r[:3]])
            src = "웹 검색"
        except Exception:
            pass
    ref_text = f"[참고 자료 — {src}]\n{ctx[:3000]}\n\n" if ctx else ""
    p = (
        f"{ref_text}"
        f"질문: {req.query}\n\n"
        "위 질문에 대해 한국어로 명확하고 구조적으로 답변하세요.\n\n"
        "## 답변\n"
        "핵심 답변을 2~4문장으로 명확하게 제시하세요. 불확실한 내용은 '~일 수 있습니다' 형태로.\n\n"
        "## 근거\n"
        "- 답변의 근거 또는 관련 개념 2~4개 (참고 자료 기반, 없으면 일반 지식 활용)\n"
        "- 각 항목에 출처 힌트 포함 가능 (예: '내 노트 참고', '교과서 원리')\n\n"
        "## 추가로 알면 좋은 것\n"
        "- 이 질문과 연관된 심화 개념 또는 응용 포인트 1~2개\n"
        "- 연관 검색어나 키워드 제안\n\n"
        "규칙: 본문 기반 우선, 없으면 일반 지식 · 이모티콘 금지 · 마지막 문장 완결"
    )
    try:
        a = await _llm(p, temp=0.3, tokens=1200)
        return {"answer": a, "source": src}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /proofread  — 글 교정
# ══════════════════════════════════════════════════════════
class ProofreadReq(BaseModel):
    content: str
    style: str = "academic"


@router.post("/proofread")
async def proofread(req: ProofreadReq):
    text = _extract_text_structured(req.content.strip())
    if _meaningful(text) < 10:
        return {"corrected": "", "changes": []}
    style_map = {
        "academic": "학술적이고 명확한",
        "casual":   "자연스럽고 친근한",
        "formal":   "공식적이고 격식 있는",
    }
    style = style_map.get(req.style, "자연스러운")
    p = (
        f"{style} 문체로 다음 글을 교정하세요.\n"
        "맞춤법, 문법, 어색한 표현을 수정하되 내용과 의미는 유지하세요.\n"
        "교정된 글만 출력하세요 (설명 없이):\n\n"
        f"{text[:3000]}"
    )
    try:
        corrected = await _llm(p, temp=0.1, tokens=2000)
        return {"corrected": corrected.strip()}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /smart-expand  — 짧은 메모/불릿을 풍부한 문단으로 확장
# ══════════════════════════════════════════════════════════
class ExpandReq(BaseModel):
    text: str                    # 확장할 짧은 텍스트 (불릿, 메모 등)
    context_title: str = ""      # 문서 제목 (선택)
    style: str = "academic"      # academic / casual / concise


@router.post("/smart-expand")
async def smart_expand(req: ExpandReq):
    if _meaningful(req.text) < 5:
        return {"expanded": ""}
    style_map = {
        "academic": "학술적이고 정확한",
        "casual":   "자연스럽고 읽기 쉬운",
        "concise":  "간결하고 핵심 중심의",
    }
    style_desc = style_map.get(req.style, "자연스러운")
    title_hint = f"문서 제목: {req.context_title}\n" if req.context_title else ""
    p = (
        f"당신은 학습 노트 작성 보조 AI입니다.\n"
        f"{title_hint}"
        f"다음 짧은 메모나 불릿을 {style_desc} 문체로 풍부하게 확장하세요.\n\n"
        f"[원문]\n{req.text[:500]}\n\n"
        "확장 규칙:\n"
        "- 원문의 핵심 의미와 주제를 유지할 것\n"
        "- 정의, 예시, 원인/결과, 또는 관련 맥락을 추가해 2~4문장으로 확장\n"
        "- 새로운 정보 추가 가능하나 원문과 모순 금지\n"
        "- 확장된 문단만 출력 (설명 없이)\n"
        "- 마지막 문장 완결"
    )
    try:
        result = await _llm(p, temp=0.4, tokens=600)
        return {"expanded": result.strip()}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /suggest-tags  — 문서 내용 기반 태그 자동 추천
# ══════════════════════════════════════════════════════════
class TagReq(BaseModel):
    content: str
    title: str = ""
    existing_tags: str = ""     # 이미 있는 태그 (제외용)


@router.post("/suggest-tags")
async def suggest_tags(req: TagReq):
    text = _extract_text_structured(req.content.strip())
    if _meaningful(text) < 20:
        return {"tags": []}
    title_hint = f"제목: {req.title}\n" if req.title else ""
    existing = f"이미 있는 태그 (이것과 겹치지 않도록): {req.existing_tags}\n" if req.existing_tags else ""
    p = (
        f"{title_hint}"
        f"{existing}"
        f"본문:\n{text[:3000]}\n\n"
        "위 학습 노트에 어울리는 태그를 5~8개 추천하세요.\n\n"
        "규칙:\n"
        "- 쉼표로 구분된 한국어 태그 목록만 출력 (설명 없이)\n"
        "- 각 태그는 1~3단어, 명사 형태\n"
        "- 주제, 과목, 핵심 개념, 난이도 등을 반영\n"
        "- 이모티콘 금지\n"
        "예시: 운영체제, 프로세스, 메모리관리, 컴퓨터구조, 중급"
    )
    try:
        result = await _llm(p, temp=0.3, tokens=200)
        tags = [t.strip() for t in result.split(",") if t.strip()]
        return {"tags": tags[:8]}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /graph  — 지식 그래프
# ══════════════════════════════════════════════════════════
class GraphReq(BaseModel):
    content: str
    title: str = ""
    tags: str = ""
    summary: str = ""


def _extract_mandatory_nodes(text: str) -> tuple[list[str], list[str], list[str]]:
    """텍스트에서 h1/h2 헤딩(branch), h3 소제목(subbranch), 굵은 텍스트(detail) 추출."""
    lines = text.splitlines()
    branches: list[str] = []   # ## → branch (root 직속, 최대 8개)
    subbranches: list[str] = []  # ### → subbranch (branch 하위)
    for line in lines:
        line = line.strip()
        m2 = re.match(r'^#{1,2}\s+(.+)', line)
        m3 = re.match(r'^###\s+(.+)', line)
        if m3:
            label = m3.group(1).strip()
            if label and len(label) <= 60:
                subbranches.append(label)
        elif m2:
            label = m2.group(1).strip()
            if label and len(label) <= 60:
                branches.append(label)
    bold_terms = re.findall(r'\*\*([^*\n]{2,40})\*\*', text)
    seen: set[str] = set(branches + subbranches)
    unique_bold: list[str] = []
    for t in bold_terms:
        t = t.strip()
        if t and t not in seen:
            seen.add(t)
            unique_bold.append(t)
    return branches[:8], subbranches[:20], unique_bold[:30]


@router.post("/graph")
async def graph(req: GraphReq):
    text = _extract_text_structured(req.content.strip())
    if _meaningful(text) < 30:
        return {"nodes": [], "edges": []}

    # 제목 또는 요약을 컨텍스트로 활용
    context_hint = ""
    if req.title:
        context_hint += f"제목: {req.title}\n"
    if req.tags:
        context_hint += f"태그: {req.tags}\n"
    if req.summary:
        context_hint += f"요약 참고:\n{req.summary[:800]}\n"

    # 문서에서 계층별 노드 사전 추출
    branches, subbranches, bold_terms = _extract_mandatory_nodes(text)

    mandatory_hint = ""
    if branches:
        mandatory_hint += "【root 직속 branch 노드 (최대 8개, 반드시 포함)】\n"
        for h in branches:
            mandatory_hint += f"  - {h}\n"
        mandatory_hint += "\n"
    if subbranches:
        mandatory_hint += "【branch 하위 subbranch 노드 (반드시 포함, 가장 가까운 branch에 연결)】\n"
        for h in subbranches:
            mandatory_hint += f"  - {h}\n"
        mandatory_hint += "\n"
    if bold_terms:
        mandatory_hint += "【detail 노드로 만들 핵심 개념 (subbranch 또는 branch 하위에 연결)】\n"
        for b in bold_terms[:20]:
            mandatory_hint += f"  - {b}\n"
        mandatory_hint += "\n"

    # 4~6단계로 퍼지는 그래프를 만들되, 화면 가독성을 위해 상한을 둔다.
    target_count = max(34, min(56, len(branches) * 6 + len(subbranches[:14]) + 8))

    p = (
        f"{context_hint}"
        f"텍스트:\n{text[:20000]}\n\n"
        f"{mandatory_hint}"
        "위 학습 내용을 마인드맵 지식 그래프 JSON으로 변환하세요.\n"
        "반드시 순수 JSON 객체만 출력하고 설명, 마크다운, 코드블록은 출력하지 마세요.\n\n"
        '{"nodes":['
        '{"id":"root","label":"주제","description":"한 줄 설명","type":"core"},'
        '{"id":"b1","label":"대섹션1","description":"한 줄 설명","type":"branch"},'
        '{"id":"b2","label":"대섹션2","description":"한 줄 설명","type":"branch"},'
        '{"id":"t1","label":"소섹션1-1","description":"한 줄 설명","type":"detail"},'
        '{"id":"c1","label":"개념1-1-a","description":"한 줄 설명","type":"detail"},'
        '{"id":"e1","label":"예시1-1-a","description":"한 줄 설명","type":"detail"},'
        '{"id":"t2","label":"소섹션2-1","description":"한 줄 설명","type":"detail"},'
        '{"id":"c2","label":"개념2-1-a","description":"한 줄 설명","type":"detail"}'
        '],"edges":['
        '{"source":"root","target":"b1","label":"포함"},'
        '{"source":"root","target":"b2","label":"포함"},'
        '{"source":"b1","target":"t1","label":"구성"},'
        '{"source":"t1","target":"c1","label":"개념"},'
        '{"source":"c1","target":"e1","label":"예시"},'
        '{"source":"b2","target":"t2","label":"구성"},'
        '{"source":"t2","target":"c2","label":"개념"}'
        "]}\n\n"
        "【핵심 규칙】\n"
        f"1. 노드 총 {target_count}개 이상 반드시 생성 (이보다 적으면 출력 실패로 간주)\n"
        "2. root 직속 branch는 4~8개만 허용 — 모든 노드를 root에 직접 연결하지 말 것\n"
        "3. 각 branch 아래를 소섹션 → 개념 → 원리/특징 → 예시/주의점 순서로 4~6단계까지 깊게 연결\n"
        "4. 위 【반드시 포함할 노드】를 하나도 빠짐없이 포함할 것\n"
        "5. 본문 텍스트에서 중요 개념·용어·원리·예시를 detail로 최대한 추출할 것\n"
        "6. 계층 엣지는 각 노드당 부모 1개를 원칙으로 하며, 교차 연결은 정말 필요한 경우 4개 이하만 추가\n"
        "7. type: core(1개) / branch(root 직속만) / detail(나머지 전부)\n"
        "8. description은 48자 이내 한 줄, id 중복 금지"
    )

    try:
        raw = await _llm(p, temp=0.15, tokens=12000)
        raw = raw.replace("```json", "").replace("```", "").strip()
        s, e = raw.find("{"), raw.rfind("}")
        if s == -1 or e == -1 or e <= s:
            return _fallback_graph_from_text(text, req.title)
        chunk = raw[s:e + 1]
        try:
            parsed = json.loads(chunk)
        except json.JSONDecodeError:
            # JSON이 잘린 경우 부분 파싱 시도
            try:
                fixed = chunk[:chunk.rfind('}', 0, len(chunk)-1)+1]
                # nodes 배열만 추출
                ni = fixed.find('"nodes"')
                if ni != -1:
                    arr_s = fixed.find('[', ni)
                    arr_e = fixed.rfind(']')
                    if arr_s != -1 and arr_e != -1:
                        nodes_json = fixed[arr_s:arr_e+1]
                        parsed = {"nodes": json.loads(nodes_json), "edges": []}
                    else:
                        return _fallback_graph_from_text(text, req.title)
                else:
                    return _fallback_graph_from_text(text, req.title)
            except Exception:
                return _fallback_graph_from_text(text, req.title)

        nodes = parsed.get("nodes", [])
        edges = parsed.get("edges", [])

        # ── LLM 결과 부족 시 헤딩·굵은텍스트로 노드 보강 ──────────────
        existing_labels = {n.get("label", "").strip().lower() for n in nodes}
        existing_ids = {n.get("id", "") for n in nodes}

        # root 노드 찾기 (branch 연결용)
        root_id = next((n["id"] for n in nodes if n.get("type") == "core"), "root")

        # branch 노드 찾기 (detail 연결용)
        branch_ids = [n["id"] for n in nodes if n.get("type") == "branch"]

        def _next_id(prefix: str) -> str:
            i = len(existing_ids)
            while f"{prefix}{i}" in existing_ids:
                i += 1
            existing_ids.add(f"{prefix}{i}")
            return f"{prefix}{i}"

        MAX_NODES = 56  # 깊은 계층 표현을 위한 상한

        # branch 보강: ## 헤딩이 누락된 경우 추가 (최대 7개)
        for i, h in enumerate(branches[:7]):
            if len(nodes) >= MAX_NODES:
                break
            if h.strip().lower() not in existing_labels:
                nid = _next_id("bx")
                nodes.append({"id": nid, "label": h[:40], "description": "", "type": "branch"})
                edges.append({"source": root_id, "target": nid, "label": "포함"})
                existing_labels.add(h.strip().lower())
                branch_ids.append(nid)

        # detail 보강: ### 헤딩만 사용 (굵은텍스트는 너무 많아서 제외)
        for h in subbranches[:20]:
            if len(nodes) >= MAX_NODES:
                break
            if h.strip().lower() not in existing_labels:
                nid = _next_id("dx")
                parent = branch_ids[len(nodes) % len(branch_ids)] if branch_ids else root_id
                nodes.append({"id": nid, "label": h[:40], "description": "", "type": "detail"})
                edges.append({"source": parent, "target": nid, "label": "구성"})
                existing_labels.add(h.strip().lower())

        normalized = _normalize_graph_payload(nodes, edges, text)
        if not normalized["nodes"]:
            return _fallback_graph_from_text(text, req.title)
        return normalized
    except Exception:
        return _fallback_graph_from_text(text, req.title)


# ══════════════════════════════════════════════════════════
# /edit-selection  — 선택 텍스트 AI 편집
# ══════════════════════════════════════════════════════════
class EditReq(BaseModel):
    selected_text: str
    instruction: str
    context: str = ""


@router.post("/edit-selection")
async def edit_selection(req: EditReq):
    if not req.selected_text.strip():
        return {"result": ""}
    p = (
        f"지시: {req.instruction}\n"
        f"{'문맥: ' + req.context[:300] if req.context else ''}\n\n"
        f"원본 텍스트:\n{req.selected_text}\n\n"
        "결과만 출력하세요. 설명, 따옴표, 코드블록 없이 바로 결과만."
    )
    try:
        result = await _llm(p, temp=0.3, tokens=800)
        result = result.strip()
        if result.startswith("```") and result.endswith("```"):
            result = "\n".join(result.split("\n")[1:-1])
        return {"result": result.strip()}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /ocr  — 이미지 텍스트 추출
# ══════════════════════════════════════════════════════════
class OcrReq(BaseModel):
    image_url: str
    language: str = "ko"


@router.post("/ocr")
async def ocr_image(req: OcrReq):
    if not req.image_url.strip():
        return {"text": ""}
    if req.image_url.startswith("data:image"):
        try:
            b64 = req.image_url.split(",", 1)[1]
        except Exception:
            return {"text": ""}
    else:
        try:
            async with httpx.AsyncClient(timeout=15.0) as c:
                r = await c.get(req.image_url)
                r.raise_for_status()
                import base64 as b64lib
                b64 = b64lib.b64encode(r.content).decode()
        except Exception as e:
            return {"text": f"이미지 다운로드 실패: {str(e)}"}

    ocr_prompt = (
        "이 이미지에서 보이는 모든 텍스트를 정확하게 추출해주세요.\n"
        "텍스트만 출력하고, 설명이나 부연은 하지 마세요.\n"
        "줄바꿈과 구조는 원본과 최대한 유사하게 유지하세요."
    )
    try:
        import base64 as b64lib
        model = _get_model()
        image_bytes = b64lib.b64decode(b64)
        response = await model.generate_content_async([
            ocr_prompt,
            {"mime_type": "image/jpeg", "data": image_bytes},
        ])
        text = response.text.strip() if response.text else ""
        return {"text": text or "텍스트를 찾을 수 없습니다."}
    except Exception:
        return {"text": "OCR 처리 중 오류가 발생했습니다."}


# ══════════════════════════════════════════════════════════
# /cache  — 캐시 관리 (Redis 기반)
# ══════════════════════════════════════════════════════════
@router.post("/cache/clear")
async def clear_cache():
    return {"cleared": True, "note": "Redis TTL 기반 캐시는 자동 만료됩니다"}


@router.get("/cache/stats")
async def cache_stats():
    return {"note": "Redis 캐시 통계는 Redis CLI에서 확인하세요"}

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
_SUMMARY_TOKENS = 8192
_SUMMARY_MAP_TOKENS = 1400


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


def _normalize_quiz_items(raw_items, fallback_text: str, count: int = 3):
    if not isinstance(raw_items, list):
        return []

    sentence_pool = [
        s.strip()
        for s in re.split(r'(?<=[.!?])\s+|\n+', fallback_text)
        if len(s.strip()) > 12
    ]
    cleaned = []

    for index, item in enumerate(raw_items[:count]):
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
    terms = _extract_study_terms(clean, limit=3)
    primary = terms[0] if terms else clean[:40] or title or "이 문단"
    meaning = clean[:180] if clean else f"{primary}에 대한 핵심 설명입니다."
    related = ", ".join(terms[:3]) if terms else primary
    return (
        f"- **핵심 의미**: {meaning}\n"
        f"- **관련 개념**: **{related}**를 중심으로 앞뒤 문맥과 연결해 이해해야 합니다.\n"
        f"- **시험 포인트**: 정의, 역할, 원인과 결과를 구분해 설명할 수 있어야 합니다."
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
    if token in {"branch", "topic", "section"}:
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
        clean_nodes.append({
            "id": node_id,
            "label": label[:80],
            "description": str(node.get("description") or "").strip()
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
    if branches:
        for branch in branches:
            if (root["id"], branch["id"]) not in connected_targets:
                clean_edges.append({"source": root["id"], "target": branch["id"], "label": "핵심"})
                connected_targets.add((root["id"], branch["id"]))

    if details:
        branch_cycle = branches or [root]
        for idx, detail in enumerate(details):
            parent = branch_cycle[idx % len(branch_cycle)]
            if (parent["id"], detail["id"]) not in connected_targets:
                clean_edges.append({"source": parent["id"], "target": detail["id"], "label": "세부"})
                connected_targets.add((parent["id"], detail["id"]))

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
        if len(terms) >= 10:
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

    branch_count = min(5, max(1, len(terms)))
    for index, term in enumerate(terms[:10], start=1):
        node_type = "branch" if index <= branch_count else "detail"
        parent = "root" if node_type == "branch" else f"n{((index - branch_count - 1) % branch_count) + 1}"
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
            "위 지시에 따라 시험 대비용 학습 노트로 충분히 자세히 정리하세요.\n"
            "본문의 주요 개념, 정의, 원리, 예시, 비교, 암기 포인트를 빠뜨리지 마세요.\n"
            "본문에 없는 내용 추가 금지. 마크다운 제목과 불릿으로 읽기 쉽게 작성하세요."
        )
    return (
        f"당신은 강의 전체를 빠짐없이 정리하는 시험 대비 학습 노트 전문가입니다.\n"
        f"{hint}제목: {title}  태그: {tags}\n\n"
        f"[본문]\n{text}\n\n"
        "아래 형식으로 충분히 자세한 학습 요약 노트를 작성하세요.\n\n"
        "## 전체 흐름\n"
        "- 강의가 다루는 큰 주제와 흐름을 3~5줄로 정리\n\n"
        "## 핵심 개념\n"
        "- **개념명**: 정의, 역할, 원리, 본문 근거를 함께 설명\n\n"
        "## 세부 내용\n"
        "- 본문에 나온 하위 개념, 구성 요소, 절차, 인과관계, 비교를 빠짐없이 정리\n\n"
        "## 시험 포인트\n"
        "- 헷갈리기 쉬운 부분, 암기해야 할 용어, 출제 가능 포인트\n\n"
        "## 핵심 정리\n"
        "- 반드시 기억할 5~8가지 포인트\n\n"
        "작성 규칙:\n"
        "- 본문에 있는 내용만 사용 (창작 금지)\n"
        "- 원문에 나온 중요한 항목은 생략하지 말기\n"
        "- 개념명·용어는 **굵게** 표시\n"
        "- 빈 섹션 출력 금지\n"
        "- 이모티콘·장식 기호 금지\n"
        "- ## 계층 구조를 적극 활용\n"
        "- 마지막 문장까지 완결된 형태로 끝내기"
    )


def _build_map_prompt(chunk: str, index: int, total: int) -> str:
    """청크 압축 프롬프트 — Map 단계"""
    return (
        f"다음 학습 내용에서 나중에 통합 요약에 반드시 들어가야 할 내용을 추출하세요. (섹션 {index + 1}/{total})\n\n"
        "규칙:\n"
        "- 개념명, 정의, 원리, 구성 요소, 예시, 비교, 암기 포인트를 포함\n"
        "- 본문에 없는 내용 추가 금지\n"
        "- bullet 형식, 10~18줄 이내\n\n"
        f"[내용]\n{chunk}\n\n"
        "핵심 추출:"
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
            "중복은 제거하되 중요한 개념, 정의, 원리, 예시, 비교, 암기 포인트는 생략하지 마세요."
        )
    return (
        f"당신은 강의 전체를 빠짐없이 정리하는 시험 대비 학습 노트 전문가입니다.\n"
        f"제목: {title}  태그: {tags}\n\n"
        f"[섹션별 핵심 분석]\n{combined}\n\n"
        "위 섹션들을 하나의 완성된 학습 노트로 통합하세요.\n\n"
        "## 전체 흐름\n"
        "- 강의가 다루는 큰 주제와 흐름\n\n"
        "## 핵심 개념\n"
        "- **개념명**: 정의, 역할, 원리, 관련 개념\n\n"
        "## 세부 내용\n"
        "- 구성 요소, 절차, 인과관계, 비교, 예시를 자연스럽게 통합\n\n"
        "## 시험 포인트\n"
        "- 헷갈리기 쉬운 부분, 암기 포인트, 출제 가능 포인트\n\n"
        "## 핵심 정리\n"
        "- 전체 내용에서 가장 중요한 5~8가지\n\n"
        "작성 규칙:\n"
        "- 섹션 간 중복 제거 후 통합\n"
        "- 중요한 항목은 생략하지 말기\n"
        "- 본문에 없는 내용 추가 금지\n"
        "- 개념명은 **굵게**\n"
        "- 자연스러운 문단 흐름 유지\n"
        "- 이모티콘·장식 기호 금지\n"
        "- 마지막 섹션까지 완결된 형태로 끝내기"
    )


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
    chunks = _semantic_chunks(raw, max_chars=1500, overlap=200)

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
        chunks = _semantic_chunks(raw, max_chars=1500, overlap=200)

        try:
            if len(chunks) == 1:
                yield _sse({"type": "progress", "message": "요약 생성 중..."})
                reduce_prompt = _build_reduce_prompt(req.title, req.tags, raw, user_instruction)
            else:
                yield _sse({"type": "progress", "message": f"{len(chunks)}개 섹션 분석 중..."})

                # Map: 병렬 청크 압축
                map_results = await asyncio.gather(*[
                    _llm(_build_map_prompt(c, i, len(chunks)), temp=0.15, tokens=_SUMMARY_MAP_TOKENS)
                    for i, c in enumerate(chunks)
                ])
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

            yield _sse({"type": "done", "text": full_text.strip()})
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
        f"당신은 대학원 수준의 학습 노트 분석 전문가입니다.\n"
        f"{title_hint}"
        f"분석할 문단:\n{req.text[:1200]}\n\n"
        "위 문단 하나에 대해서만 분석합니다. 본문에 없는 내용 추가 금지.\n\n"
        "아래 형식으로 정확히 출력하세요:\n\n"
        "- **핵심 의미**: 이 문단의 핵심을 2~3문장으로 설명\n"
        "- **관련 개념**: 연결되는 개념, 배경, 헷갈리기 쉬운 지점\n"
        "- **시험 포인트**: 시험에서 어떤 식으로 물을 수 있는지\n"
        "- **한 줄 정리**: 기억해야 할 결론\n\n"
        "규칙: 본문 기반 · 개념명 **굵게** · 이모티콘 금지 · 빈 항목 금지"
    )
    try:
        result = await _llm(p, temp=0.15, tokens=900)
        return {"analysis": result if _meaningful(result) > 35 else _fallback_analysis(req.text, req.context_title)}
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
        f"본문:\n{text[:5000]}\n\n"
        "시험 직전에 볼 수 있는 핵심 암기 노트를 작성하세요. 본문에 있는 내용만 사용하고 창작은 금지합니다.\n\n"
        "## 핵심 개념\n"
        "아래 표를 완성하세요 (반드시 헤더와 구분선 포함, 최소 5행 이상):\n\n"
        "| 개념 | 설명 | 중요도 |\n"
        "|------|------|--------|\n"
        "| 개념명 | 한 줄 정의 | ★★★ |\n\n"
        "## 암기 포인트\n"
        "- **개념명**: 헷갈리기 쉬운 점과 기억할 내용을 함께 정리\n\n"
        "## 빠른 복습\n"
        "- 시험 전에 마지막으로 확인할 문장 5~8개\n\n"
        "작성 규칙:\n"
        "- 표는 반드시 완결된 형태로 출력 (잘리지 않게)\n"
        "- 개념명은 **굵게**\n"
        "- 중요도: ★★★(매우중요) / ★★(중요) / ★(보통)\n"
        "- 이모티콘 금지\n"
        "- 본문에 없는 내용 추가 금지"
    )
    try:
        r = await _llm(p, temp=0.15, tokens=2000)
        return {"memo": r if _meaningful(r) > 80 else _fallback_memo(text, req.title)}
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
    count: int = 3


@router.post("/quiz")
async def quiz(req: QuizReq):
    text = _extract_text_structured(req.content.strip())
    if _meaningful(text) < 30:
        return {"quiz": []}
    p = (
        f"본문:\n{text[:5000]}\n\n"
        f"위 본문으로 객관식 {req.count}문제를 만드세요.\n\n"
        "중요: JSON 배열만 출력하세요. 그 외 텍스트 절대 금지.\n"
        "형식: [{\"question\":\"질문\",\"options\":[\"A\",\"B\",\"C\",\"D\"],\"answer\":0,\"explanation\":\"해설\"}]\n\n"
        "규칙:\n"
        "- question: 구체적인 질문 (본문 기반, Q번호 포함 가능)\n"
        "- options: 정확히 4개 문자열 배열\n"
        "- answer: 정답 인덱스 정수 (0, 1, 2, 3 중 하나)\n"
        "- explanation: 정답 근거 (본문 기반, 2~3문장)\n"
        "- 쉬운 문제만 만들지 말고 개념 비교, 원인/결과, 역할을 섞기\n"
        "- 본문에 없는 내용으로 문제 생성 금지\n"
        "- JSON이 끊기지 않도록 완결된 배열로 끝내기"
    )
    try:
        raw = await _llm(p, temp=0.1, tokens=2200)
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
                        return {"quiz": _fallback_quiz(text, req.count)}
                else:
                    return {"quiz": _fallback_quiz(text, req.count)}
            normalized = _normalize_quiz_items(parsed, text, req.count)
            return {"quiz": normalized if normalized else _fallback_quiz(text, req.count)}

        obj_start, obj_end = raw.find("{"), raw.rfind("}")
        if obj_start != -1 and obj_end != -1 and obj_end > obj_start:
            parsed_obj = json.loads(raw[obj_start:obj_end + 1])
            raw_quiz = parsed_obj.get("quiz") or parsed_obj.get("questions") or []
            normalized = _normalize_quiz_items(raw_quiz, text, req.count)
            return {"quiz": normalized if normalized else _fallback_quiz(text, req.count)}

        return {"quiz": _fallback_quiz(text, req.count)}
    except Exception:
        return {"quiz": _fallback_quiz(text, req.count)}


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
    ref_text = f"[참고 자료 — {src}]\n{ctx[:2500]}\n\n" if ctx else ""
    p = (
        f"{ref_text}"
        f"질문: {req.query}\n\n"
        "위 질문에 대해 한국어로 명확하고 구조적으로 답변하세요.\n\n"
        "답변 형식:\n"
        "- 핵심 답변을 첫 문장에 바로 제시\n"
        "- 필요하면 불릿이나 번호 목록으로 구조화\n"
        "- 근거나 예시가 있으면 간략히 포함\n"
        "- 불확실한 내용은 '~일 수 있습니다' 형태로 표현\n"
        "- 200자~500자 이내로 간결하게"
    )
    try:
        a = await _llm(p, temp=0.3, tokens=800)
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
# /graph  — 지식 그래프
# ══════════════════════════════════════════════════════════
class GraphReq(BaseModel):
    content: str
    title: str = ""
    tags: str = ""
    summary: str = ""


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

    p = (
        f"{context_hint}"
        f"텍스트:\n{text[:5000]}\n\n"
        "아래 학습 내용을 마인드맵 지식 그래프로 변환하세요.\n"
        "반드시 순수 JSON 객체만 출력하고 설명, 마크다운, 코드블록은 출력하지 마세요.\n\n"
        '{"nodes":['
        '{"id":"root","label":"주제","description":"한 줄 설명","type":"core"},'
        '{"id":"n1","label":"핵심개념1","description":"한 줄 설명","type":"branch"},'
        '{"id":"n2","label":"세부개념1","description":"한 줄 설명","type":"detail"}'
        '],"edges":['
        '{"source":"root","target":"n1","label":"포함"},'
        '{"source":"n1","target":"n2","label":"구성"}'
        "]}\n\n"
        "규칙:\n"
        "- type: core(루트 1개) / branch(핵심 3~5개) / detail(세부)\n"
        "- 노트의 큰 제목/단원을 branch로 만들고, 하위 개념을 detail로 만들기\n"
        "- 반드시 root → branch → detail 계층 연결\n"
        "- 노드 8~16개, 엣지 7개 이상 생성\n"
        "- description은 35자 이내 한 줄\n"
        "- id는 영문+숫자 조합 (root, n1, n2 ...)\n"
        "- 중복 id 금지"
    )

    try:
        raw = await _llm(p, temp=0.12, tokens=2400)
        raw = raw.replace("```json", "").replace("```", "").strip()
        s, e = raw.find("{"), raw.rfind("}")
        if s == -1 or e == -1 or e <= s:
            return _fallback_graph_from_text(text, req.title)
        chunk = raw[s:e + 1]
        try:
            parsed = json.loads(chunk)
        except json.JSONDecodeError:
            return _fallback_graph_from_text(text, req.title)

        nodes = parsed.get("nodes", [])
        edges = parsed.get("edges", [])
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

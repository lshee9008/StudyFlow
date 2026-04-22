from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, List, AsyncGenerator
import json, httpx, re, asyncio, hashlib, time as _time
from collections import OrderedDict

router = APIRouter()
OLLAMA = "http://localhost:11434/api/generate"
MODEL  = "gemma3:27b-cloud"

# ── LRU 캐시 (메모리, 100개, TTL 1h) ─────────────────────
_llm_cache: OrderedDict = OrderedDict()
_CACHE_MAX  = 100
_CACHE_TTL  = 3600

def _cache_key(prompt: str, temp: float, tokens: int) -> str:
    return hashlib.md5(f"{prompt}|{temp}|{tokens}".encode()).hexdigest()


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
            if   t == "h1":       parts.append(f"# {c}")
            elif t == "h2":       parts.append(f"## {c}")
            elif t == "h3":       parts.append(f"### {c}")
            elif t == "bullet":   parts.append(f"- {c}")
            elif t == "number":   parts.append(f"1. {c}")
            elif t == "checkbox": parts.append(f"☐ {c}")
            elif t == "quote":    parts.append(f"> {c}")
            elif t == "code":     parts.append(f"```\n{c}\n```")
            elif t == "divider":  parts.append("---")
            else:                 parts.append(c)
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
        if tail and not tail[-1] in '.。\n':
            idx = max(tail.rfind(' '), tail.rfind('\n'))
            if idx > len(tail) // 2:
                tail = tail[idx + 1:]
        result.append(f"[앞 내용 연결]\n{tail}\n\n{raw[i]}" if tail else raw[i])
    return result


# ══════════════════════════════════════════════════════════
# LLM 호출 — 비스트리밍 (캐시 포함)
# ══════════════════════════════════════════════════════════
async def _llm(prompt: str, temp: float = 0.2, tokens: int = 1500) -> str:
    key = _cache_key(prompt, temp, tokens)
    if key in _llm_cache:
        entry = _llm_cache[key]
        if _time.time() - entry['ts'] < _CACHE_TTL:
            _llm_cache.move_to_end(key)
            return entry['val']
        del _llm_cache[key]

    async with httpx.AsyncClient(timeout=120.0) as c:
        r = await c.post(OLLAMA, json={
            "model": MODEL, "prompt": prompt, "stream": False,
            "options": {"temperature": temp, "num_predict": tokens,
                        "top_p": 0.85, "repeat_penalty": 1.1}
        })
        r.raise_for_status()
        result = r.json().get("response", "").strip()

    if len(_llm_cache) >= _CACHE_MAX:
        _llm_cache.popitem(last=False)
    _llm_cache[key] = {'val': result, 'ts': _time.time()}
    return result


# ══════════════════════════════════════════════════════════
# LLM 스트리밍 제너레이터
# ══════════════════════════════════════════════════════════
async def _llm_stream(prompt: str, temp: float = 0.2, tokens: int = 2000) -> AsyncGenerator[str, None]:
    """Ollama stream=True → 토큰 단위 async generator"""
    async with httpx.AsyncClient(timeout=120.0) as c:
        async with c.stream("POST", OLLAMA, json={
            "model": MODEL, "prompt": prompt, "stream": True,
            "options": {"temperature": temp, "num_predict": tokens,
                        "top_p": 0.85, "repeat_penalty": 1.1}
        }) as response:
            async for line in response.aiter_lines():
                if not line.strip():
                    continue
                try:
                    data = json.loads(line)
                    token = data.get("response", "")
                    if token:
                        yield token
                    if data.get("done", False):
                        break
                except json.JSONDecodeError:
                    continue


# ══════════════════════════════════════════════════════════
# 프롬프트 빌더
# ══════════════════════════════════════════════════════════
def _structure_hint(text: str) -> str:
    h1s = [l[2:].strip() for l in text.split('\n') if l.startswith('# ')]
    return f"문서 주제: {' / '.join(h1s[:4])}\n" if h1s else ""


def _build_reduce_prompt(title: str, tags: str, text: str, user_instruction: str = "") -> str:
    """단일 청크 — 직접 요약 프롬프트"""
    hint = _structure_hint(text)
    if user_instruction:
        return (
            f"사용자 지시: {user_instruction}\n"
            f"{hint}제목: {title}  태그: {tags}\n\n"
            f"[본문]\n{text}\n\n"
            "위 지시에 따라 마크다운으로 정리하세요. 본문에 없는 내용 추가 금지."
        )
    return (
        f"당신은 대학원 수준의 학습 노트 전문가입니다.\n"
        f"{hint}제목: {title}  태그: {tags}\n\n"
        f"[본문]\n{text}\n\n"
        "아래 형식으로 구조화된 학습 요약 노트를 작성하세요.\n\n"
        "## 핵심 개념\n"
        "- **개념명**: 정의 및 원리 (본문 근거 포함)\n\n"
        "## 상세 내용\n"
        "- 세부 설명, 과정, 인과관계\n\n"
        "## 핵심 정리\n"
        "- 반드시 기억할 3~5가지 포인트\n\n"
        "작성 규칙:\n"
        "- 본문에 있는 내용만 사용 (창작 금지)\n"
        "- 개념명·용어는 **굵게** 표시\n"
        "- 빈 섹션 출력 금지\n"
        "- 이모티콘·장식 기호 금지\n"
        "- ## 계층 구조를 적극 활용"
    )


def _build_map_prompt(chunk: str, index: int, total: int) -> str:
    """청크 압축 프롬프트 — Map 단계"""
    return (
        f"다음 학습 내용의 핵심만 간결하게 추출하세요. (섹션 {index + 1}/{total})\n\n"
        "규칙:\n"
        "- 개념명과 정의는 반드시 포함\n"
        "- 본문에 없는 내용 추가 금지\n"
        "- bullet 형식, 5~8줄 이내\n\n"
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
            "위 지시에 따라 하나의 완성된 노트로 통합하세요. 중복 제거, 자연스러운 흐름 유지."
        )
    return (
        f"당신은 대학원 수준의 학습 노트 전문가입니다.\n"
        f"제목: {title}  태그: {tags}\n\n"
        f"[섹션별 핵심 분석]\n{combined}\n\n"
        "위 섹션들을 하나의 완성된 학습 노트로 통합하세요.\n\n"
        "## 핵심 개념\n"
        "- **개념명**: 정의 (섹션 간 중복 통합)\n\n"
        "## 상세 내용\n"
        "- 원리, 과정, 세부사항 (자연스러운 흐름)\n\n"
        "## 핵심 정리\n"
        "- 전체 내용에서 가장 중요한 3~5가지\n\n"
        "작성 규칙:\n"
        "- 섹션 간 중복 제거 후 통합\n"
        "- 본문에 없는 내용 추가 금지\n"
        "- 개념명은 **굵게**\n"
        "- 자연스러운 문단 흐름 유지\n"
        "- 이모티콘·장식 기호 금지"
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
            result = await _llm(prompt, temp=0.2, tokens=2000)
        else:
            map_results = await asyncio.gather(*[
                _llm(_build_map_prompt(c, i, len(chunks)), temp=0.15, tokens=500)
                for i, c in enumerate(chunks)
            ])
            valid = [r for r in map_results if _meaningful(r) > 10]
            if not valid:
                return {"summary": ""}
            merge_prompt = _build_merge_prompt(req.title, req.tags, valid, user_instruction)
            result = await _llm(merge_prompt, temp=0.2, tokens=2000)

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
                    _llm(_build_map_prompt(c, i, len(chunks)), temp=0.15, tokens=500)
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
            async for token in _llm_stream(reduce_prompt, temp=0.2, tokens=2000):
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
    p = (
        f"제목: {req.context_title}\n"
        f"내용: {req.text[:600]}\n\n"
        "위 내용을 3줄로 분석하세요 (마크다운):\n"
        "- **핵심 의미**: 이 내용이 말하는 것\n"
        "- **관련 개념/주의사항**: 연결되는 배경지식 또는 함정\n"
        "- **실제 활용**: 어디에 쓰이는지 (없으면 생략)"
    )
    try:
        return {"analysis": await _llm(p, temp=0.2, tokens=400)}
    except Exception:
        return {"analysis": ""}


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
        f"본문: {text[:3000]}\n\n"
        "시험에 나올 핵심 암기 사항만 추출하세요 (본문에 있는 내용만):\n\n"
        "## 핵심 개념\n"
        "| 개념 | 설명 | 중요도 |\n"
        "|------|------|--------|\n\n"
        "## 암기 포인트\n"
        "- **개념**: 한 줄 설명"
    )
    try:
        r = await _llm(p, temp=0.15, tokens=1000)
        return {"memo": r if _meaningful(r) > 20 else ""}
    except Exception as e:
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
        f"본문: {text[:3000]}\n\n"
        f"위 본문으로 객관식 {req.count}문제를 만드세요.\n"
        "순수 JSON 배열만 출력 (설명 없이):\n"
        '[{"question":"?","options":["A","B","C","D"],"answer":0,"explanation":"근거"}]'
    )
    try:
        raw = await _llm(p, temp=0.1, tokens=900)
        raw = raw.replace("```json", "").replace("```", "").strip()
        s, e = raw.find("["), raw.rfind("]")
        if s != -1 and e != -1:
            return {"quiz": json.loads(raw[s:e + 1])}
        return {"quiz": []}
    except Exception:
        return {"quiz": []}


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
    ref_text = f"참고 ({src}):\n{ctx[:2500]}\n\n" if ctx else ""
    p = f"{ref_text}질문: {req.query}\n\n간결하고 정확하게 한국어로 답변:"
    try:
        a = await _llm(p, temp=0.3, tokens=700)
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


@router.post("/graph")
async def graph(req: GraphReq):
    text = _extract_text_structured(req.content.strip())
    if _meaningful(text) < 30:
        return {"nodes": [], "edges": []}
    p = (
        f"텍스트: {text[:2000]}\n\n"
        "핵심 키워드 최대 12개와 관계를 순수 JSON으로만 출력:\n"
        '{"nodes":[{"id":"개념","label":"개념","type":"main"}],'
        '"edges":[{"source":"A","target":"B","label":"관계"}]}\n\n'
        "type은 main(핵심개념), sub(하위개념), detail(세부사항) 중 하나."
    )
    try:
        raw = await _llm(p, temp=0.1, tokens=600)
        raw = raw.replace("```json", "").replace("```", "").strip()
        s, e = raw.find("{"), raw.rfind("}")
        if s != -1 and e != -1:
            return json.loads(raw[s:e + 1])
        return {"nodes": [], "edges": []}
    except Exception:
        return {"nodes": [], "edges": []}


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
        async with httpx.AsyncClient(timeout=60.0) as c:
            r = await c.post(OLLAMA, json={
                "model": MODEL, "prompt": ocr_prompt,
                "images": [b64], "stream": False,
                "options": {"temperature": 0.1, "num_predict": 2000}
            })
            r.raise_for_status()
            text = r.json().get("response", "").strip()
            return {"text": text or "텍스트를 찾을 수 없습니다."}
    except Exception:
        return {"text": "OCR 처리 중 오류가 발생했습니다."}


# ══════════════════════════════════════════════════════════
# /cache  — 캐시 관리
# ══════════════════════════════════════════════════════════
@router.post("/cache/clear")
async def clear_cache():
    _llm_cache.clear()
    return {"cleared": True}


@router.get("/cache/stats")
async def cache_stats():
    valid = sum(1 for v in _llm_cache.values() if _time.time() - v['ts'] < _CACHE_TTL)
    return {"total": len(_llm_cache), "valid": valid, "max": _CACHE_MAX}

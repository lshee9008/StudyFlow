from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import json, httpx, re, asyncio

router = APIRouter()
OLLAMA = "http://localhost:11434/api/generate"
MODEL = "gemma3:27b-cloud"

# ── 요청 캐시 (최대 100개, 메모리) ──────────────────────
import hashlib
from collections import OrderedDict

_llm_cache: OrderedDict = OrderedDict()
_CACHE_MAX = 100
_CACHE_TTL = 3600  # 1시간 (초)

def _cache_key(prompt: str, temp: float, tokens: int) -> str:
    raw = f"{prompt}|{temp}|{tokens}"
    return hashlib.md5(raw.encode()).hexdigest()


# ══════════════════════════════════════════════════════════
# LLM 호출
# ══════════════════════════════════════════════════════════
async def _llm(prompt: str, temp: float = 0.25, tokens: int = 1500) -> str:
    import time
    key = _cache_key(prompt, temp, tokens)
    # 캐시 히트 확인
    if key in _llm_cache:
        entry = _llm_cache[key]
        if time.time() - entry['ts'] < _CACHE_TTL:
            _llm_cache.move_to_end(key)  # LRU 갱신
            return entry['val']
        else:
            del _llm_cache[key]
    # LLM 호출
    async with httpx.AsyncClient(timeout=120.0) as c:
        r = await c.post(OLLAMA, json={
            "model": MODEL, "prompt": prompt, "stream": False,
            "options": {"temperature": temp, "num_predict": tokens,
                        "top_p": 0.85, "repeat_penalty": 1.1}})
        r.raise_for_status()
        result = r.json().get("response", "").strip()
    # 캐시 저장 (크기 초과 시 가장 오래된 항목 제거)
    if len(_llm_cache) >= _CACHE_MAX:
        _llm_cache.popitem(last=False)
    _llm_cache[key] = {'val': result, 'ts': time.time()}
    return result


def _meaningful(text: str) -> int:
    return len(re.sub(r'\s', '', text))


def _extract_text(content: str) -> str:
    """JSON 블록 배열에서 실제 텍스트 추출"""
    try:
        blocks = json.loads(content)
        parts = []
        for b in blocks:
            if not isinstance(b, dict): continue
            t = b.get("type", "text")
            c = (b.get("content") or b.get("controller", {}).get("text") or "").strip()
            if not c: continue
            if t == "h1":
                parts.append(f"# {c}")
            elif t == "h2":
                parts.append(f"## {c}")
            elif t == "h3":
                parts.append(f"### {c}")
            elif t == "bullet":
                parts.append(f"- {c}")
            elif t == "checkbox":
                parts.append(f"☐ {c}")
            elif t == "code":
                parts.append(f"```\n{c}\n```")
            else:
                parts.append(c)
        return "\n".join(parts)
    except Exception:
        return content


def _chunk_text(text: str, max_chars: int = 3000) -> List[str]:
    """긴 텍스트를 의미 단위(문단)로 청킹"""
    if len(text) <= max_chars:
        return [text]

    chunks, current = [], []
    current_len = 0

    for para in text.split('\n\n'):
        if current_len + len(para) > max_chars and current:
            chunks.append('\n\n'.join(current))
            current = [para]
            current_len = len(para)
        else:
            current.append(para)
            current_len += len(para)

    if current:
        chunks.append('\n\n'.join(current))

    return chunks


# ══════════════════════════════════════════════════════════
# /summarize  — 긴 글은 청크 병렬 처리로 속도 개선
# ══════════════════════════════════════════════════════════
class SumReq(BaseModel):
    content: str
    tags: str = ""
    title: str = ""
    custom_prompt: Optional[str] = None
    # 서버 단 프롬프트 (파일의 prompt 필드)
    server_prompt: Optional[str] = None


@router.post("/summarize")
async def summarize(req: SumReq):
    raw = _extract_text(req.content.strip())
    if _meaningful(raw) < 20:
        return {"summary": ""}

    # ── 프롬프트 우선순위: custom_prompt > server_prompt > 기본값
    user_instruction = req.custom_prompt or req.server_prompt or ""
    is_long = len(raw) > 2000

    if user_instruction:
        system = f"""사용자 지시: {user_instruction}

위 지시에 따라 아래 본문을 분석하고 마크다운으로 정리하세요.
본문에 없는 내용 창작 금지."""
    else:
        system = f"""당신은 최고의 학습 노트 AI입니다.
제목: {req.title}  태그: {req.tags}

아래 본문을 **구조화된 학습 요약 노트**로 작성하세요.

출력 형식:
## 핵심 개념
- 주요 개념과 정의 (굵게 **강조**)

## 상세 내용
- 세부 설명과 원리
{"- 비교/관계는 마크다운 표로 정리" if is_long else ""}

## 핵심 정리
- 가장 중요한 3-5가지

규칙: 본문 내용만 사용 · 이모티콘 금지 · 빈 템플릿 금지"""

    # ── 긴 글: 청크로 분할 후 병렬 처리 → 속도 대폭 향상
    chunks = _chunk_text(raw, max_chars=2500)

    if len(chunks) == 1:
        # 짧은 글: 단순 처리
        prompt = f"{system}\n\n[본문]:\n{raw}\n\n[요약]:"
        try:
            result = await _llm(prompt, temp=0.2, tokens=1800)
            return {"summary": result if _meaningful(result) > 10 else ""}
        except Exception as e:
            raise HTTPException(500, str(e))
    else:
        # 긴 글: 청크별 병렬 요약 후 통합
        async def summarize_chunk(chunk: str, i: int) -> str:
            p = f"다음 내용을 간결하게 요약하세요 (파트 {i + 1}/{len(chunks)}).\n본문에 있는 내용만 사용:\n\n{chunk}\n\n요약:"
            try:
                return await _llm(p, temp=0.15, tokens=600)
            except:
                return ""

        # 병렬 실행
        chunk_results = await asyncio.gather(*[
            summarize_chunk(c, i) for i, c in enumerate(chunks)
        ])

        valid = [r for r in chunk_results if _meaningful(r) > 10]
        if not valid:
            return {"summary": ""}

        # 청크 요약들을 최종 통합
        combined = "\n\n".join(f"[파트 {i + 1}]\n{r}" for i, r in enumerate(valid))
        final_prompt = f"""{system}

[분할 요약본]:
{combined}

위 분할 요약들을 하나의 완성된 학습 노트로 통합하세요:"""
        try:
            final = await _llm(final_prompt, temp=0.2, tokens=2000)
            return {"summary": final if _meaningful(final) > 10 else "\n\n".join(valid)}
        except Exception as e:
            return {"summary": "\n\n".join(valid)}


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
    p = f"""제목: {req.context_title}
내용: {req.text[:500]}

위 내용을 3줄로 분석하세요 (마크다운):
- 핵심 의미
- 관련 개념/주의사항
- 실제 활용 (있으면)"""
    try:
        return {"analysis": await _llm(p, temp=0.2, tokens=350)}
    except:
        return {"analysis": ""}


# ══════════════════════════════════════════════════════════
# /memo  — 핵심 암기 노트
# ══════════════════════════════════════════════════════════
class MemoReq(BaseModel):
    content: str
    title: str = ""


@router.post("/memo")
async def memo(req: MemoReq):
    text = _extract_text(req.content.strip())
    if _meaningful(text) < 20:
        return {"memo": ""}
    p = f"""제목: {req.title}
본문: {text[:3000]}

시험에 나올 핵심 암기 사항만 추출하세요 (본문에 있는 내용만):

## 핵심 개념
| 개념 | 설명 | 중요도 |
|------|------|--------|

## 암기 포인트
- **개념**: 설명"""
    try:
        r = await _llm(p, temp=0.2, tokens=800)
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
    text = _extract_text(req.content.strip())
    if _meaningful(text) < 30:
        return {"quiz": []}
    p = f"""본문: {text[:3000]}

위 본문으로 객관식 {req.count}문제. 순수 JSON 배열만 출력:
[{{"question":"?","options":["A","B","C","D"],"answer":0,"explanation":"근거"}}]"""
    try:
        raw = await _llm(p, temp=0.1, tokens=900)
        raw = raw.replace("```json", "").replace("```", "").strip()
        s, e = raw.find("["), raw.rfind("]")
        if s != -1 and e != -1:
            return {"quiz": json.loads(raw[s:e + 1])}
        return {"quiz": []}
    except:
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
    except:
        pass
    if not ctx and req.use_web_search:
        try:
            from app.core.web_search import get_web_search_tool
            r = get_web_search_tool().invoke(req.query)
            ctx = "\n".join([x['content'] for x in r[:3]])
            src = "웹 검색"
        except:
            pass
    ref_text = f"참고 ({src}):\n{ctx[:2500]}\n\n" if ctx else ""
    p = f"{ref_text}질문: {req.query}\n\n간결하고 정확하게 한국어로 답변:"
    try:
        a = await _llm(p, temp=0.3, tokens=600)
        return {"answer": a, "source": src}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /proofread  — 글 교정 (신규)
# ══════════════════════════════════════════════════════════
class ProofreadReq(BaseModel):
    content: str
    style: str = "academic"  # academic / casual / formal


@router.post("/proofread")
async def proofread(req: ProofreadReq):
    text = _extract_text(req.content.strip())
    if _meaningful(text) < 10:
        return {"corrected": "", "changes": []}

    style_map = {
        "academic": "학술적이고 명확한",
        "casual": "자연스럽고 친근한",
        "formal": "공식적이고 격식 있는",
    }
    style = style_map.get(req.style, "자연스러운")

    p = f"""{style} 문체로 다음 글을 교정하세요.
맞춤법, 문법, 어색한 표현을 수정하되 내용과 의미는 유지하세요.
교정된 글만 출력하세요 (설명 없이):

{text[:3000]}"""
    try:
        corrected = await _llm(p, temp=0.1, tokens=2000)
        return {"corrected": corrected.strip()}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /graph  — 지식 그래프 (마인드맵 데이터)
# ══════════════════════════════════════════════════════════
class GraphReq(BaseModel):
    content: str


@router.post("/graph")
async def graph(req: GraphReq):
    text = _extract_text(req.content.strip())
    if _meaningful(text) < 30:
        return {"nodes": [], "edges": []}

    p = f"""텍스트: {text[:2000]}

핵심 키워드 최대 12개와 관계를 순수 JSON으로만 출력:
{{"nodes":[{{"id":"개념","label":"개념","type":"main"}}],"edges":[{{"source":"A","target":"B","label":"관계"}}]}}

type은 main(핵심개념), sub(하위개념), detail(세부사항) 중 하나."""
    try:
        raw = await _llm(p, temp=0.1, tokens=500)
        raw = raw.replace("```json", "").replace("```", "").strip()
        s, e = raw.find("{"), raw.rfind("}")
        if s != -1 and e != -1:
            return json.loads(raw[s:e + 1])
        return {"nodes": [], "edges": []}
    except:
        return {"nodes": [], "edges": []}


# ══════════════════════════════════════════════════════════
# /edit-selection  — 선택된 텍스트 AI 편집 (노션 AI 편집 기능)
# ══════════════════════════════════════════════════════════
class EditReq(BaseModel):
    selected_text: str
    instruction: str  # 사용자 지시 (개선, 교정, 설명, 번역 등)
    context: str = ""  # 주변 문맥 (옵션)


@router.post("/edit-selection")
async def edit_selection(req: EditReq):
    if not req.selected_text.strip():
        return {"result": ""}

    prompt = f"""다음 텍스트에 대해 아래 지시를 수행하세요.

지시: {req.instruction}
{"문맥: " + req.context[:300] if req.context else ""}

원본 텍스트:
{req.selected_text}

결과만 출력하세요. 설명, 따옴표, 마크다운 코드블록 없이 바로 결과만."""

    try:
        result = await _llm(prompt, temp=0.3, tokens=800)
        # 불필요한 마크다운 코드블록 제거
        result = result.strip()
        if result.startswith("```") and result.endswith("```"):
            lines = result.split("\n")
            result = "\n".join(lines[1:-1])
        return {"result": result.strip()}
    except Exception as e:
        raise HTTPException(500, str(e))


# ══════════════════════════════════════════════════════════
# /cache/clear  — 캐시 초기화 (관리자용)
# ══════════════════════════════════════════════════════════
@router.post("/cache/clear")
async def clear_cache():
    _llm_cache.clear()
    return {"cleared": True}


@router.get("/cache/stats")
async def cache_stats():
    import time
    valid = sum(1 for v in _llm_cache.values() if time.time() - v['ts'] < _CACHE_TTL)
    return {"total": len(_llm_cache), "valid": valid, "max": _CACHE_MAX}
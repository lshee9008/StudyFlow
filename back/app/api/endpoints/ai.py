from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import json, httpx, re

router = APIRouter()
OLLAMA = "http://localhost:11434/api/generate"
MODEL  = "gemma3:27b-cloud"

async def _llm(prompt: str, temp: float = 0.25, tokens: int = 1200) -> str:
    async with httpx.AsyncClient(timeout=90.0) as c:
        r = await c.post(OLLAMA, json={
            "model": MODEL, "prompt": prompt, "stream": False,
            "options": {"temperature": temp, "num_predict": tokens,
                        "top_p": 0.85, "repeat_penalty": 1.15}})
        r.raise_for_status()
        return r.json().get("response", "").strip()

def _meaningful(text: str) -> int:
    """공백/줄바꿈 제외 실제 글자 수"""
    return len(re.sub(r'\s', '', text))

# ─── 요약 ────────────────────────────────────────────────────
class SumReq(BaseModel):
    content: str; tags: str = ""; title: str = ""; custom_prompt: Optional[str] = None

@router.post("/summarize")
async def summarize(req: SumReq):
    text = req.content.strip()
    mc   = _meaningful(text)

    # ✅ 핵심: 실제 내용이 충분하지 않으면 즉시 빈 응답
    if mc < 20:
        return {"summary": ""}

    # 실제 내용 추출 (JSON 블록 제거)
    try:
        blocks = json.loads(text)
        raw = " ".join([b.get("content","") for b in blocks if isinstance(b,dict)])
        if _meaningful(raw) < 20:
            return {"summary": ""}
        text = raw
    except Exception:
        pass

    text = text[:4500]

    cp = req.custom_prompt or ""
    base = f"""당신은 학습 내용을 분석하는 AI입니다.

⚠️ 절대 규칙:
1. 반드시 아래 [본문]에 실제로 있는 내용만 요약하세요
2. 본문에 없는 내용을 추측하거나 창작하면 안 됩니다
3. 본문 내용이 부족하면 "더 많은 내용을 작성해 주세요"라고만 응답하세요
4. 이모티콘 사용 금지
5. 빈 템플릿/표 형식 절대 사용 금지

{f'사용자 지시: {cp}' if cp else '구조화된 마크다운으로 핵심 내용만 요약하세요.'}

[본문]:
{text}

[요약]:"""

    try:
        res = await _llm(base, temp=0.2, tokens=1200)
        if not res or len(res) < 20:
            return {"summary": ""}
        return {"summary": res}
    except Exception as e:
        raise HTTPException(500, str(e))


# ─── 블록 분석 ────────────────────────────────────────────────
class BlockReq(BaseModel):
    text: str; context_title: str = ""

@router.post("/analyze-block")
async def analyze_block(req: BlockReq):
    if _meaningful(req.text) < 15:
        return {"analysis": ""}
    p = f"""다음 문장을 3줄로 간결하게 분석하세요. 본문에 없는 내용 창작 금지.

제목: {req.context_title}
내용: {req.text[:400]}

분석 (마크다운):"""
    try:
        return {"analysis": await _llm(p, temp=0.2, tokens=250)}
    except:
        return {"analysis": ""}


# ─── 암기 노트 ────────────────────────────────────────────────
class MemoReq(BaseModel):
    content: str; title: str = ""

@router.post("/memo")
async def memo(req: MemoReq):
    text = req.content.strip()
    if _meaningful(text) < 20:
        return {"memo": ""}
    try:
        blocks = json.loads(text)
        text = " ".join([b.get("content","") for b in blocks if isinstance(b,dict)])
    except: pass
    if _meaningful(text) < 20:
        return {"memo": ""}

    p = f"""제목: {req.title}
본문: {text[:3000]}

위 본문에서 핵심 암기 사항만 추출하세요 (본문에 없는 내용 창작 금지):

## 핵심 개념
(본문에서 추출한 개념만)

## 암기 포인트  
- **개념**: 설명"""
    try:
        r = await _llm(p, temp=0.2, tokens=700)
        return {"memo": r if _meaningful(r) > 20 else ""}
    except Exception as e:
        raise HTTPException(500, str(e))


# ─── 퀴즈 ────────────────────────────────────────────────────
class QuizReq(BaseModel):
    content: str; count: int = 3

@router.post("/quiz")
async def quiz(req: QuizReq):
    text = req.content.strip()
    if _meaningful(text) < 30:
        return {"quiz": []}
    try:
        blocks = json.loads(text)
        text = " ".join([b.get("content","") for b in blocks if isinstance(b,dict)])
    except: pass
    if _meaningful(text) < 30:
        return {"quiz": []}

    p = f"""본문: {text[:3000]}

위 본문 내용으로만 객관식 {req.count}문제를 만드세요.
반드시 순수 JSON 배열만 출력 (마크다운 금지):
[{{"question":"?","options":["A","B","C","D"],"answer":0,"explanation":"본문 근거"}}]"""
    try:
        raw = await _llm(p, temp=0.1, tokens=900)
        raw = raw.replace("```json","").replace("```","").strip()
        s,e = raw.find("["), raw.rfind("]")
        if s!=-1 and e!=-1:
            return {"quiz": json.loads(raw[s:e+1])}
        return {"quiz": []}
    except Exception as e:
        return {"quiz": []}


# ─── Ask (RAG) ────────────────────────────────────────────────
class AskReq(BaseModel):
    query: str; project_id: str; use_web_search: bool = True

@router.post("/ask")
async def ask(req: AskReq):
    if not req.query.strip():
        raise HTTPException(400,"empty")
    ctx, src = "", "일반 지식"
    try:
        from app.core.vector_store import get_vector_store
        vs = get_vector_store()
        docs = vs.similarity_search_with_score(req.query, k=4,
            filter={"project_id": req.project_id})
        rel = [(d,s) for d,s in docs if s < 0.6]
        if rel:
            ctx = "\n\n".join([d.page_content for d,_ in rel]); src = "내 노트"
    except: pass
    if not ctx and req.use_web_search:
        try:
            from app.core.web_search import get_web_search_tool
            r = get_web_search_tool().invoke(req.query)
            ctx = "\n".join([x['content'] for x in r[:3]]); src = "웹 검색"
        except: pass
    ref_text = f"참고 ({src}):\n{ctx[:2500]}\n\n" if ctx else ""
    p = f"{ref_text}질문: {req.query}\n\n간결하고 정확하게 한국어로 답변:"
    try:
        a = await _llm(p, temp=0.3, tokens=600)
        return {"answer": a, "source": src}
    except Exception as e:
        raise HTTPException(500, str(e))


# ─── 지식 그래프 ──────────────────────────────────────────────
class GraphReq(BaseModel):
    content: str

@router.post("/graph")
async def graph(req: GraphReq):
    text = req.content.strip()
    if _meaningful(text) < 30:
        return {"nodes":[],"edges":[]}
    try:
        blocks = json.loads(text)
        text = " ".join([b.get("content","") for b in blocks if isinstance(b,dict)])
    except: pass
    p = f"""텍스트: {text[:1800]}

핵심 키워드 최대 10개와 연결 관계를 순수 JSON으로만 출력:
{{"nodes":[{{"id":"개념","label":"개념"}}],"edges":[{{"source":"A","target":"B"}}]}}"""
    try:
        raw = await _llm(p, temp=0.1, tokens=400)
        raw = raw.replace("```json","").replace("```","").strip()
        s,e = raw.find("{"),raw.rfind("}")
        if s!=-1 and e!=-1:
            return json.loads(raw[s:e+1])
        return {"nodes":[],"edges":[]}
    except:
        return {"nodes":[],"edges":[]}
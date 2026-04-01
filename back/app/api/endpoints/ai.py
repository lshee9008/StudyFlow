from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, List
import json
import httpx
import asyncio

from app.core.vector_store import get_vector_store
from app.core.web_search import get_web_search_tool

router = APIRouter()

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "gemma3:27b-cloud"


# ── 공통 Ollama 호출 (스트리밍 없이 빠른 응답) ──────────────
async def _call_ollama(prompt: str, temperature: float = 0.3, max_tokens: int = 1500) -> str:
    async with httpx.AsyncClient(timeout=90.0) as client:
        resp = await client.post(OLLAMA_URL, json={
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": temperature,
                "num_predict": max_tokens,
                "top_p": 0.9,
                "repeat_penalty": 1.1,
            }
        })
        resp.raise_for_status()
        return resp.json().get("response", "")


# ═══════════════════════════════════════════════════════════
# /summarize  —  스마트 요약 (내용 품질 검사 포함)
# ═══════════════════════════════════════════════════════════
class SummaryRequest(BaseModel):
    content: str
    tags: str = ""
    custom_prompt: Optional[str] = None
    title: str = ""


@router.post("/summarize")
async def summarize_content(req: SummaryRequest):
    # ① 내용 품질 체크 — 너무 짧거나 의미 없는 내용이면 거절
    stripped = req.content.strip()
    meaningful_chars = len([c for c in stripped if c.strip()])

    if meaningful_chars < 50:
        return {"summary": ""}  # 빈 응답 → UI에서 빈 상태 표시

    # ② 프롬프트 구성
    base_context = f"""제목: {req.title}
태그: {req.tags}
본문:
{stripped[:4000]}"""  # 최대 4000자 (속도 최적화)

    if req.custom_prompt and len(req.custom_prompt.strip()) > 10:
        # 사용자 커스텀 지시사항 있을 때
        system = f"""{req.custom_prompt}

위 지시사항에 따라 아래 내용을 분석하고 **한국어 마크다운**으로 정리하세요.
규칙: 이모티콘 사용 금지. 존재하지 않는 내용 절대 창작 금지. 
반드시 실제 본문에 있는 내용만 사용하세요."""
    else:
        system = """당신은 최고의 학습 보조 AI입니다. 아래 본문을 읽고 **실제 내용에 기반한** 구조화된 요약 노트를 작성하세요.

작성 규칙:
1. 반드시 실제 본문에 있는 내용만 사용 (없는 내용 절대 창작 금지)
2. 핵심 개념과 중요 사항을 계층적으로 정리
3. 필요시 마크다운 표, 코드 블록, 리스트 활용
4. 이모티콘 사용 금지
5. 학술적이고 명확한 문체 사용
6. 섹션 헤더(##)로 구분하여 가독성 확보"""

    prompt = f"{system}\n\n{base_context}\n\n---\n요약 노트:"

    try:
        result = await _call_ollama(prompt, temperature=0.2, max_tokens=1500)
        return {"summary": result.strip()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ═══════════════════════════════════════════════════════════
# /ask  —  Hybrid RAG (내 노트 + 웹 검색)
# ═══════════════════════════════════════════════════════════
class AskRequest(BaseModel):
    query: str
    project_id: str
    use_web_search: bool = True


@router.post("/ask")
async def ask_ai(req: AskRequest):
    if not req.query.strip():
        raise HTTPException(status_code=400, detail="Query is empty")

    context_text = ""
    source_type = "내 노트"

    # 1. 벡터 검색
    try:
        vector_store = get_vector_store()
        docs = vector_store.similarity_search_with_score(
            req.query, k=4, filter={"project_id": req.project_id})

        # 유사도 임계값 (ChromaDB 거리: 낮을수록 유사)
        relevant = [(d, s) for d, s in docs if s < 0.65]
        if relevant:
            context_text = "\n\n".join([d.page_content for d, _ in relevant])
    except Exception as e:
        print(f"Vector search error: {e}")

    # 2. 웹 검색 (내 노트에 정보 없을 때)
    if not context_text and req.use_web_search:
        try:
            web_tool = get_web_search_tool()
            results = web_tool.invoke(req.query)
            context_text = "\n".join([r['content'] for r in results[:3]])
            source_type = "웹 검색"
        except Exception as e:
            print(f"Web search error: {e}")
            context_text = ""

    # 3. AI 응답 생성
    if context_text:
        prompt = f"""참고 정보 ({source_type}):
{context_text[:3000]}

---
질문: {req.query}

위 참고 정보를 바탕으로 정확하고 간결하게 답변하세요. 
참고 정보에 없는 내용은 명시적으로 언급하세요.
한국어로 답변하세요."""
    else:
        prompt = f"""질문: {req.query}

위 질문에 대해 알고 있는 내용을 바탕으로 정확하게 답변하세요.
한국어로 답변하세요."""

    try:
        answer = await _call_ollama(prompt, temperature=0.3, max_tokens=800)
        return {"answer": answer.strip(), "source": source_type}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ═══════════════════════════════════════════════════════════
# /analyze-block  —  포커스 블록 즉시 분석 (빠름)
# ═══════════════════════════════════════════════════════════
class BlockAnalyzeRequest(BaseModel):
    text: str
    context_title: str = ""


@router.post("/analyze-block")
async def analyze_block(req: BlockAnalyzeRequest):
    if len(req.text.strip()) < 10:
        return {"analysis": ""}

    prompt = f"""다음 문단을 3-4줄로 심층 분석하세요.
문서 제목: {req.context_title}
분석할 내용: {req.text[:500]}

분석 항목:
- 핵심 의미 1-2줄
- 관련 개념 또는 주의사항 1줄
- 실제 활용/예시 1줄 (있는 경우)

간결하고 명확하게 마크다운으로 작성하세요."""

    try:
        result = await _call_ollama(prompt, temperature=0.2, max_tokens=300)
        return {"analysis": result.strip()}
    except Exception as e:
        return {"analysis": ""}


# ═══════════════════════════════════════════════════════════
# /memo  —  핵심 암기 노트
# ═══════════════════════════════════════════════════════════
class MemoRequest(BaseModel):
    content: str
    title: str = ""


@router.post("/memo")
async def generate_memo(req: MemoRequest):
    if len(req.content.strip()) < 50:
        return {"memo": ""}

    prompt = f"""제목: {req.title}
본문:
{req.content[:3000]}

---
위 내용에서 시험이나 실무에 꼭 필요한 핵심 암기 사항 5-7개를 추출하세요.

형식:
## 핵심 개념

| 개념 | 설명 | 중요도 |
|------|------|--------|
| ... | ... | ⭐⭐⭐ |

## 암기 포인트
- **개념명**: 설명 (반드시 본문에 있는 내용만)

본문에 없는 내용은 절대 추가하지 마세요."""

    try:
        result = await _call_ollama(prompt, temperature=0.2, max_tokens=800)
        return {"memo": result.strip()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ═══════════════════════════════════════════════════════════
# /quiz  —  인터랙티브 퀴즈 생성
# ═══════════════════════════════════════════════════════════
class QuizRequest(BaseModel):
    content: str
    count: int = 3


@router.post("/quiz")
async def generate_quiz(req: QuizRequest):
    if len(req.content.strip()) < 100:
        return {"quiz": []}

    prompt = f"""본문:
{req.content[:3000]}

---
위 본문에서 객관식 퀴즈 {req.count}문제를 만드세요.
반드시 아래 순수 JSON 배열만 출력하세요 (다른 텍스트 금지):

[
  {{
    "question": "문제 내용",
    "options": ["보기1", "보기2", "보기3", "보기4"],
    "answer": 0,
    "explanation": "해설 (본문 근거 포함)"
  }}
]

규칙:
- 반드시 본문 내용에 기반한 문제만 출제
- answer는 0-3 사이 정수 (options 인덱스)
- 명확하고 객관적인 정답이 있어야 함"""

    try:
        raw = await _call_ollama(prompt, temperature=0.1, max_tokens=1000)
        # JSON 파싱
        clean = raw.replace("```json", "").replace("```", "").strip()
        start, end = clean.find("["), clean.rfind("]")
        if start != -1 and end != -1:
            quiz_data = json.loads(clean[start:end + 1])
            return {"quiz": quiz_data}
        return {"quiz": []}
    except Exception as e:
        print(f"Quiz parse error: {e}")
        return {"quiz": []}


# ═══════════════════════════════════════════════════════════
# /graph  —  지식 그래프 추출
# ═══════════════════════════════════════════════════════════
class GraphRequest(BaseModel):
    content: str


@router.post("/graph")
async def extract_graph(req: GraphRequest):
    if len(req.content.strip()) < 30:
        return {"nodes": [], "edges": []}

    prompt = f"""텍스트:
{req.content[:2000]}

---
위 텍스트에서 핵심 키워드(최대 10개)와 관계를 추출하세요.
반드시 아래 순수 JSON만 출력하세요 (다른 텍스트 금지):

{{
  "nodes": [
    {{"id": "개념명", "label": "개념명"}}
  ],
  "edges": [
    {{"source": "개념A", "target": "개념B"}}
  ]
}}"""

    try:
        raw = await _call_ollama(prompt, temperature=0.1, max_tokens=500)
        clean = raw.replace("```json", "").replace("```", "").strip()
        start, end = clean.find("{"), clean.rfind("}")
        if start != -1 and end != -1:
            return json.loads(clean[start:end + 1])
        return {"nodes": [], "edges": []}
    except Exception as e:
        print(f"Graph parse error: {e}")
        return {"nodes": [], "edges": []}


# ═══════════════════════════════════════════════════════════
# /proofread  —  글 교정
# ═══════════════════════════════════════════════════════════
class ProofreadRequest(BaseModel):
    content: str
    style: str = "academic"


@router.post("/proofread")
async def proofread(req: ProofreadRequest):
    style_map = {
        "academic": "학술적이고 명확한",
        "casual": "자연스럽고 친근한",
        "formal": "공식적이고 격식 있는"
    }
    style = style_map.get(req.style, "자연스러운")

    prompt = f"""{style} 문체로 다음 글을 교정하세요.
맞춤법, 문법, 어색한 표현을 수정하되 내용과 의미는 유지하세요.
교정된 글만 출력하세요 (설명 없이):

{req.content[:2000]}"""

    try:
        result = await _call_ollama(prompt, temperature=0.1, max_tokens=2000)
        return {"corrected": result.strip()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
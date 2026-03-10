from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import json

from app.core.vector_store import get_vector_store
from app.core.web_search import get_web_search_tool

from langchain_community.chat_models import ChatOllama
from langchain_core.messages import SystemMessage, HumanMessage

router = APIRouter()

# 🚨 [수정 완료] 요청하신 gemma3:27b-cloud 모델로 세팅했습니다.
llm = ChatOllama(model="gemma3:27b-cloud", temperature=0.3)


class AskRequest(BaseModel):
    query: str
    project_id: str
    use_web_search: bool = True


class SummaryRequest(BaseModel):
    content: str
    tags: str
    custom_prompt: Optional[str] = None


@router.post("/ask")
async def ask_ai(req: AskRequest):
    """
    [Hybrid RAG] 내 노트 검색 -> (정보 부족 시) -> 웹 검색
    """
    vector_store = get_vector_store()
    docs = vector_store.similarity_search_with_score(
        req.query,
        k=3,
        filter={"project_id": req.project_id}
    )

    context_text = ""
    source_type = "내 노트"

    is_relevant = False
    if docs and docs[0][1] < 0.7:  # 유사도 기준 (가까울수록 좋음)
        is_relevant = True
        context_text = "\n\n".join([d[0].page_content for d in docs])

    if not is_relevant and req.use_web_search:
        print("🔍 내 노트에 정보 부족. 웹 검색 실행...")
        try:
            web_tool = get_web_search_tool()
            web_results = web_tool.invoke(req.query)
            web_context = "\n".join([res['content'] for res in web_results])
            context_text = f"인터넷 검색 결과:\n{web_context}"
            source_type = "인터넷 검색"
        except Exception as e:
            print(f"Web search failed: {e}")
            context_text = "관련 정보를 찾을 수 없습니다."

    # [진짜 AI 호출] RAG 프롬프트
    messages = [
        SystemMessage(
            content=f"당신은 똑똑한 학습 보조 AI입니다. 다음 제공된 출처({source_type})의 정보를 바탕으로 사용자의 질문에 친절하고 정확하게 답하세요.\n\n출처 정보:\n{context_text}"),
        HumanMessage(content=req.query)
    ]

    print(f"🤖 [gemma3:27b-cloud] AI가 답변을 생성 중입니다...")
    response = llm.invoke(messages)

    return {"answer": response.content, "source": source_type}


@router.post("/summarize")
async def summarize_content(req: SummaryRequest):
    """
    [Dual-Track] 요약/분석/퀴즈 생성
    """
    system_prompt = req.custom_prompt if req.custom_prompt else "다음 내용을 아주 깔끔하게 정리해주세요."

    # [진짜 AI 호출]
    messages = [
        SystemMessage(content=system_prompt),
        HumanMessage(content=f"본문 내용:\n{req.content}")
    ]

    print(f"🤖 [gemma3:27b-cloud] AI가 요청을 처리 중입니다... (데이터 크기: {len(req.content)}자)")
    response = llm.invoke(messages)

    return {"summary": response.content}
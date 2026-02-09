from typing import List

from pydantic import BaseModel
import httpx
from fastapi import APIRouter, Depends
from sqlmodel import Session
from app.core.database import get_session
from app.models.files import FileCreate, FileRead
from app.crud import crud_files

import uuid

router = APIRouter()

@router.post("/", response_model=FileRead)
def create_files(
    *, session: Session = Depends(get_session), file_in: FileCreate
):
    return crud_files.create_files(session, file_in)

# 요청 데이터 모델 정의
class SummaryRequest(BaseModel):
    content: str  # 노트 본문 내용
    tags: str  # 사용자가 입력한 태그 (예: "회의, 중요")
    custom_prompt: str  # 사용자의 요구사항 (예: "3줄로 요약해줘")

@router.post("/summarize")
async def summarize_note(request: SummaryRequest):
    # 1. Ollama에게 보낼 최종 프롬프트 구성
    system_instruction = (
        f"You are a helpful AI assistant. "
        f"Context/Tags: {request.tags}."
        f"User's Instruction: {request.custom_prompt}. "
        f"Please summarize the following content accordingly:"
    )

    full_prompt = f"{system_instruction}\n\nContent:\n{request.content}"

    # 2. Ollama API 호출 (비동기)
    try:
        async with httpx.AsyncClient() as client:
            # Ollama API 엔드포인트 (로컬)
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "gemma3:4b",  # 또는 사용하시는 모델명 (gemma:4b 등)
                    "prompt": full_prompt,
                    "stream": False
                },
                timeout=60.0  # 생성 시간이 걸릴 수 있으므로 넉넉하게
            )

            response.raise_for_status()
            result = response.json()
            return {"summary": result.get("response", "")}

    except Exception as e:
        print(f"Ollama Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 서버에서 대충 uuid로 userid 할당되게끔만 로그인 서비스는 늦어질 수도 있으니 이정도만 되게끔 해주고 메인푸시
# 파일 작업 하고 너는 로그인/홈/프로젝트 작업 하고!!!
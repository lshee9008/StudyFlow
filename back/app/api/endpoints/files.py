from pydantic import BaseModel
import httpx
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
from app.core.database import get_session
from app.models.files import FileCreate, FileRead
from app.crud import crud_files

router = APIRouter()

@router.post("/", response_model=FileRead)
def create_files(
    *, session: Session = Depends(get_session), file_in: FileCreate
):
    return crud_files.create_files(session, file_in)

class SummaryRequest(BaseModel):
    content: str
    tags: str
    custom_prompt: str

@router.post("/summarize")
async def summarize_note(request: SummaryRequest):
    # 💡 [수정] 제한적인 1타 강사 모드 해제 -> 완벽한 'AI 학습 스튜디오' 모드로 변경
    system_instruction = (
        f"당신은 사용자의 노트를 완벽하게 분석하고 구조화하는 '최고의 AI 학습 스튜디오 어시스턴트'입니다.\n"
        f"관련 태그: {request.tags}\n"
        f"요청 사항: {request.custom_prompt}\n"
        f"반드시 마크다운(Markdown) 포맷(이모지, 리스트, 표 등)을 적극 활용하여 가장 가독성 좋고 세련된 한국어(Korean)로 답변하세요."
    )

    full_prompt = f"{system_instruction}\n\n[사용자 작성 본문]:\n{request.content}"

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "gemma3:27b-cloud",
                    "prompt": full_prompt,
                    "stream": False,
                    "options": {
                        "temperature": 0.4, # 구조화와 창의성의 완벽한 밸런스
                        "num_predict": 2048, # 💡 [핵심] 사용자의 글이 잘리지 않도록 답변 길이를 대폭 늘림 (기존 512 -> 2048)
                    }
                }
            )

            response.raise_for_status()
            result = response.json()
            return {"summary": result.get("response", "")}

    except Exception as e:
        print(f"☁️ AI Cloud Error: {e}")
        raise HTTPException(status_code=500, detail=f"AI 서버 응답 지연: {str(e)}")
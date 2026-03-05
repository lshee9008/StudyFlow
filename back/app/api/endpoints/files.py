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
    # 💡 [수정] AI에게 TMI 금지령 내리기
    system_instruction = (
        f"당신은 군더더기 없이 핵심만 찌르는 1타 강사 AI입니다.\n"
        f"관련 태그: {request.tags}\n"
        f"요청 사항: {request.custom_prompt}\n"
        f"절대 장황하게 설명(TMI)하거나 인사말을 하지 마세요. 반드시 마크다운(Markdown)을 사용하여 가독성 좋고, 짧고 명확하게 한국어로 답변하세요."
    )

    full_prompt = f"{system_instruction}\n\n[분석 대상]:\n{request.content}"

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "gemma3:27b-cloud",
                    "prompt": full_prompt,
                    "stream": False,
                    "options": {
                        "temperature": 0.3, # 💡 답변을 더 건조하고 팩트 위주로 생성
                        "num_predict": 512, # 너무 길어지는 것 원천 차단
                    }
                }
            )

            response.raise_for_status()
            result = response.json()
            return {"summary": result.get("response", "")}

    except Exception as e:
        print(f"☁️ AI Cloud Error: {e}")
        raise HTTPException(status_code=500, detail=f"AI 서버 오류: {str(e)}")
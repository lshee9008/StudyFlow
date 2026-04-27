import uuid
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from pydantic import BaseModel
import httpx

from app.core.database import get_session
from app.models.files import Files, FileCreate, FileRead
from app.crud import crud_files

router = APIRouter()


# ── 파일 생성 ──────────────────────────────────────────────
@router.post("/", response_model=FileRead)
def create_file(*, session: Session = Depends(get_session), file_in: FileCreate):
    return crud_files.create_file(session, file_in)


# ── 프로젝트의 파일 목록 조회 ──────────────────────────────
@router.get("/project/{project_id}", response_model=List[FileRead])
def get_files_by_project(
    project_id: uuid.UUID,
    session: Session = Depends(get_session)
):
    return crud_files.get_files_by_project(session, project_id)


# ── 특정 파일 조회 ────────────────────────────────────────
@router.get("/{file_id}", response_model=FileRead)
def get_file(*, session: Session = Depends(get_session), file_id: uuid.UUID):
    file = session.get(Files, file_id)
    if not file:
        raise HTTPException(status_code=404, detail="File not found")
    return file


# ── 파일 업데이트 ──────────────────────────────────────────
class FileUpdateRequest(BaseModel):
    title: Optional[str] = None
    tags: Optional[str] = None
    icon: Optional[str] = None
    prompt: Optional[str] = None
    content: Optional[str] = None
    summary: Optional[str] = None
    graph: Optional[str] = None

@router.put("/{file_id}", response_model=FileRead)
def update_file(
    file_id: uuid.UUID,
    file_in: FileUpdateRequest,
    session: Session = Depends(get_session)
):
    file = session.get(Files, file_id)
    if not file:
        raise HTTPException(status_code=404, detail="File not found")
    data = file_in.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(file, key, value)
    session.add(file)
    session.commit()
    session.refresh(file)

    # RAG 벡터 업데이트 (content 변경 시)
    if file_in.content is not None:
        _update_vector(file)

    return file


# ── 파일 삭제 ──────────────────────────────────────────────
@router.delete("/{file_id}")
def delete_file(*, session: Session = Depends(get_session), file_id: uuid.UUID):
    file = session.get(Files, file_id)
    if not file:
        raise HTTPException(status_code=404, detail="File not found")
    session.delete(file)
    session.commit()
    return {"message": "File deleted successfully"}


# ── 서버 사이드 AI 요약 (프롬프트 포함) ──────────────────────
class ServerSummarizeRequest(BaseModel):
    file_id: str
    content: str
    title: str
    tags: str = ""
    custom_prompt: Optional[str] = None   # 사용자 커스텀 프롬프트

@router.post("/summarize-with-prompt")
async def summarize_with_prompt(req: ServerSummarizeRequest):
    """
    파일의 prompt 필드를 서버에서 읽어 AI에 적용.
    클라이언트는 prompt를 보내지 않아도 됨.
    """
    # 서버 프롬프트 우선, 없으면 기본값
    system_prompt = req.custom_prompt or (
        f"다음 내용을 구조화된 마크다운 노트로 정리해 주세요.\n"
        f"제목: {req.title}\n태그: {req.tags}"
    )

    full_prompt = f"{system_prompt}\n\n[본문]:\n{req.content}"

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "gemma3:27b-cloud",
                    "prompt": full_prompt,
                    "stream": False,
                    "options": {"temperature": 0.4, "num_predict": 2048}
                }
            )
            response.raise_for_status()
            result = response.json()
            return {"summary": result.get("response", "")}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 서버 오류: {str(e)}")


# ── 글 교정 API ───────────────────────────────────────────
class ProofreadRequest(BaseModel):
    content: str
    style: str = "academic"  # academic / casual / formal

@router.post("/proofread")
async def proofread_content(req: ProofreadRequest):
    style_map = {
        "academic": "학술적이고 명확한 문체",
        "casual":   "자연스럽고 친근한 문체",
        "formal":   "공식적이고 격식 있는 문체",
    }
    style_desc = style_map.get(req.style, "자연스러운 문체")

    prompt = (
        f"다음 글을 {style_desc}로 교정해 주세요.\n"
        "맞춤법, 문법, 어색한 표현을 수정하되 내용은 유지하세요.\n"
        "교정된 글만 출력하고, 설명이나 부연은 하지 마세요.\n\n"
        f"[원문]\n{req.content}"
    )

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "gemma3:27b-cloud",
                    "prompt": prompt,
                    "stream": False,
                    "options": {"temperature": 0.2, "num_predict": 2048}
                }
            )
            response.raise_for_status()
            result = response.json()
            return {"corrected": result.get("response", "")}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 서버 오류: {str(e)}")


# ── RAG 벡터 업데이트 헬퍼 ────────────────────────────────
def _update_vector(file: Files):
    try:
        from app.core.vector_store import get_vector_store
        import langchain_core.documents
        vector_store = get_vector_store()
        doc = langchain_core.documents.Document(
            page_content=file.content or "",
            metadata={
                "file_id": str(file.id),
                "project_id": str(file.project_id),
                "title": file.title or "무제",
            }
        )
        vector_store.add_documents([doc])
        print(f"✅ [RAG] File {file.id} re-embedded.")
    except Exception as e:
        print(f"❌ [RAG] Vector update failed: {e}")

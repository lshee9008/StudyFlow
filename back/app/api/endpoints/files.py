from typing import Optional, List
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlmodel import Session, select
from pydantic import BaseModel
import google.generativeai as genai

from app.core.config import settings
from app.core.database import get_session
from app.models.files import Files, FileCreate, FileRead
from app.models.projects import Projects
from app.crud import crud_files


def _gemini(prompt: str, temp: float = 0.2, tokens: int = 2048) -> str:
    if not settings.GEMINI_API_KEY:
        raise RuntimeError("GEMINI_API_KEY is not configured")
    genai.configure(api_key=settings.GEMINI_API_KEY)
    model = genai.GenerativeModel(settings.GEMINI_MODEL)
    cfg = genai.types.GenerationConfig(temperature=temp, max_output_tokens=tokens)
    response = model.generate_content(prompt, generation_config=cfg)
    return response.text.strip() if response.text else ""

router = APIRouter()


# ── 파일 생성 ──────────────────────────────────────────────
@router.post("/", response_model=FileRead)
def create_file(*, session: Session = Depends(get_session), file_in: FileCreate):
    return crud_files.create_file(session, file_in)


# ── 프로젝트의 파일 목록 조회 ──────────────────────────────
@router.get("/project/{project_id}", response_model=List[FileRead])
def get_files_by_project(
    project_id: str,
    session: Session = Depends(get_session)
):
    return crud_files.get_files_by_project(session, project_id)


# ── 특정 파일 조회 ────────────────────────────────────────
@router.get("/{file_id}", response_model=FileRead)
def get_file(*, session: Session = Depends(get_session), file_id: str):
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
    memo: Optional[str] = None

@router.put("/{file_id}", response_model=FileRead)
def update_file(
    file_id: str,
    file_in: FileUpdateRequest,
    background_tasks: BackgroundTasks,
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

    # RAG 벡터 업데이트 (content 변경 시) - 백그라운드로 실행하여 응답 지연 방지
    if file_in.content is not None:
        background_tasks.add_task(_update_vector, file)

    return file


# ── 유저의 최근 수정 파일 목록 ────────────────────────────────
@router.get("/user/{user_id}/recent", response_model=List[FileRead])
def get_recent_files(
    user_id: str,
    limit: int = 8,
    session: Session = Depends(get_session),
):
    """유저의 모든 프로젝트에서 최근 수정된 파일 목록 반환."""
    projects = session.exec(
        select(Projects).where(Projects.user_id == user_id)
    ).all()
    project_ids = [p.id for p in projects]
    if not project_ids:
        return []
    files = session.exec(
        select(Files)
        .where(Files.project_id.in_(project_ids))
        .order_by(Files.update_at.desc())
        .limit(limit)
    ).all()
    return files


# ── 파일 삭제 ──────────────────────────────────────────────
@router.delete("/{file_id}")
def delete_file(*, session: Session = Depends(get_session), file_id: str):
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
    ai.py 의 _build_reduce_prompt 를 그대로 사용해 일관된 품질 보장.
    """
    import json
    import re

    def _extract(content: str) -> str:
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
                elif t == "code":
                    parts.append(f"```\n{c}\n```")
                else:
                    parts.append(c)
            return "\n\n".join(parts)
        except Exception:
            return content

    raw = _extract(req.content.strip())
    if len(re.sub(r'\s', '', raw)) < 20:
        return {"summary": ""}

    user_instruction = req.custom_prompt or ""

    if user_instruction:
        full_prompt = (
            f"사용자 지시: {user_instruction}\n"
            f"제목: {req.title}  태그: {req.tags}\n\n"
            f"[본문]\n{raw}\n\n"
            "위 지시에 따라 마크다운으로 정리하세요. 본문에 없는 내용 추가 금지."
        )
    else:
        h1s = [line[2:].strip() for line in raw.split('\n') if line.startswith('# ')]
        hint = f"문서 주제: {' / '.join(h1s[:4])}\n" if h1s else ""
        full_prompt = (
            f"당신은 대학원 수준의 학습 노트 전문가입니다.\n"
            f"{hint}제목: {req.title}  태그: {req.tags}\n\n"
            f"[본문]\n{raw}\n\n"
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
            "- ## 계층 구조를 적극 활용\n"
            "- 마지막 문장까지 완결된 형태로 끝내기"
        )

    try:
        result = _gemini(full_prompt, temp=0.2, tokens=3000)
        return {"summary": result if result.strip() else ""}
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
        result = _gemini(prompt, temp=0.2, tokens=2048)
        return {"corrected": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI 서버 오류: {str(e)}")


# ── RAG 벡터 업데이트 헬퍼 ────────────────────────────────
def _update_vector(file: Files):
    try:
        from app.core.vector_store import get_vector_store
        from app.crud.crud_files import _extract_plain_text
        import langchain_core.documents
        vector_store = get_vector_store()
        # JSON 블록 배열 → 순수 텍스트로 임베딩 (검색 품질 향상)
        plain_text = _extract_plain_text(file.content or "")
        if not plain_text.strip():
            return
        doc = langchain_core.documents.Document(
            page_content=plain_text,
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

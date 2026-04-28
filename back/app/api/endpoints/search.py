from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import List, Optional
from sqlmodel import Session, select
import uuid

from app.core.database import get_session
from app.models.files import Files
from app.models.projects import Projects

router = APIRouter()


class SearchRequest(BaseModel):
    query: str
    user_id: str
    project_id: Optional[str] = None
    limit: int = 10


class SearchResult(BaseModel):
    file_id: str
    project_id: str
    title: str
    content_preview: str
    score: float
    tags: str


@router.post("/semantic", response_model=List[SearchResult])
def semantic_search(req: SearchRequest, session: Session = Depends(get_session)):
    """
    Vector DB를 활용한 의미 기반 검색.
    유저의 모든 노트에서 의미적으로 유사한 내용 검색.
    """
    results = []

    try:
        from app.core.vector_store import get_vector_store
        vector_store = get_vector_store()

        search_kwargs = {"k": req.limit}
        if req.project_id:
            search_kwargs["filter"] = {"project_id": req.project_id}

        docs = vector_store.similarity_search_with_score(req.query, **search_kwargs)

        for doc, score in docs:
            # 유사도 임계값 (ChromaDB는 거리 기반: 낮을수록 유사)
            if score > 1.2:
                continue

            file_id = doc.metadata.get("file_id", "")
            file = session.get(Files, uuid.UUID(file_id)) if file_id else None
            if not file:
                continue

            # 유저 소유 검증
            project = session.get(Projects, file.project_id)
            if not project or str(project.user_id) != req.user_id:
                continue

            preview = (doc.page_content[:150] + "...") if len(doc.page_content) > 150 else doc.page_content

            results.append(SearchResult(
                file_id=file_id,
                project_id=str(file.project_id),
                title=file.title or "제목 없음",
                content_preview=preview,
                score=round(1 - score, 3),  # 0~1 유사도로 변환
                tags=file.tags or "",
            ))

    except Exception as e:
        print(f"[Search] Vector search failed: {e}")
        # Vector 검색 실패 시 키워드 검색으로 폴백
        return keyword_search_internal(req, session)

    return sorted(results, key=lambda x: x.score, reverse=True)


@router.post("/keyword", response_model=List[SearchResult])
def keyword_search(req: SearchRequest, session: Session = Depends(get_session)):
    return keyword_search_internal(req, session)


def keyword_search_internal(req: SearchRequest, session: Session) -> List[SearchResult]:
    """SQLite LIKE 기반 키워드 검색"""
    q = req.query.lower()

    # 유저의 모든 프로젝트 가져오기
    user_projects = session.exec(
        select(Projects).where(Projects.user_id == uuid.UUID(req.user_id))
    ).all()

    project_ids = [p.id for p in user_projects]
    if req.project_id:
        try:
            project_ids = [uuid.UUID(req.project_id)]
        except Exception:
            pass

    results = []
    for pid in project_ids:
        files = session.exec(select(Files).where(Files.project_id == pid)).all()
        for f in files:
            score = 0.0
            if f.title and q in f.title.lower():
                score += 0.8
            if f.content and q in f.content.lower():
                score += 0.5
            if f.tags and q in f.tags.lower():
                score += 0.3
            if score == 0:
                continue

            content = f.content or ""
            # 검색어 주변 컨텍스트 추출
            idx = content.lower().find(q)
            if idx != -1:
                start = max(0, idx - 60)
                end = min(len(content), idx + 120)
                preview = ("..." if start > 0 else "") + content[start:end] + ("..." if end < len(content) else "")
            else:
                preview = content[:150] + ("..." if len(content) > 150 else "")

            results.append(SearchResult(
                file_id=str(f.id),
                project_id=str(f.project_id),
                title=f.title or "제목 없음",
                content_preview=preview,
                score=min(score, 1.0),
                tags=f.tags or "",
            ))

    return sorted(results, key=lambda x: x.score, reverse=True)[:req.limit]

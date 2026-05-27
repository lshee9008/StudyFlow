import json
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlmodel import Session, select

from app.core.database import get_session
from app.models.files import Files
from app.models.projects import Projects

router = APIRouter()


# ──────────────────────────────────────────────
# 헬퍼: JSON 블록 배열 → 순수 텍스트 추출
# ──────────────────────────────────────────────
def extract_plain_text(content: str) -> str:
    """
    Files.content 는 JSON 블록 배열:
    [{"type": "text", "content": "..."}, ...]
    이를 파싱해 각 블록의 content 값을 줄바꿈으로 이어붙인 순수 텍스트를 반환한다.
    파싱에 실패하면 원본 문자열을 그대로 반환한다.
    """
    if not content:
        return ""
    try:
        blocks = json.loads(content)
        if isinstance(blocks, list):
            parts = []
            for b in blocks:
                if isinstance(b, dict):
                    text = (b.get("content") or "").strip()
                    if text:
                        parts.append(text)
            return "\n".join(parts)
    except Exception:
        pass
    return content


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

        for doc, distance in docs:
            # ChromaDB 거리 기반: 낮을수록 유사 (0 = 완전 동일)
            # 1.2 초과 시 유사도가 너무 낮으므로 skip
            if distance > 1.2:
                continue

            file_id = doc.metadata.get("file_id", "")
            file = session.get(Files, uuid.UUID(file_id)) if file_id else None
            if not file:
                continue

            # 유저 소유 검증
            project = session.get(Projects, file.project_id)
            if not project or str(project.user_id) != req.user_id:
                continue

            # 순수 텍스트로 미리보기 생성
            plain = extract_plain_text(doc.page_content)
            preview = (plain[:150] + "...") if len(plain) > 150 else plain

            # 유사도 점수: 거리 → 0~1 변환 (거리가 클수록 낮은 점수)
            similarity = max(0.0, round(1.0 - distance, 3))

            results.append(SearchResult(
                file_id=file_id,
                project_id=str(file.project_id),
                title=file.title or "제목 없음",
                content_preview=preview,
                score=similarity,
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
            # JSON 블록 배열 → 순수 텍스트
            plain_content = extract_plain_text(f.content or "")

            score = 0.0
            if f.title and q in f.title.lower():
                score += 0.8
            if plain_content and q in plain_content.lower():
                score += 0.5
            if f.tags and q in f.tags.lower():
                score += 0.3
            if score == 0:
                continue

            # 검색어 주변 컨텍스트 추출 (순수 텍스트 기준)
            idx = plain_content.lower().find(q)
            if idx != -1:
                start = max(0, idx - 60)
                end = min(len(plain_content), idx + 120)
                preview = (
                    ("..." if start > 0 else "")
                    + plain_content[start:end]
                    + ("..." if end < len(plain_content) else "")
                )
            else:
                preview = plain_content[:150] + ("..." if len(plain_content) > 150 else "")

            results.append(SearchResult(
                file_id=str(f.id),
                project_id=str(f.project_id),
                title=f.title or "제목 없음",
                content_preview=preview,
                score=min(score, 1.0),
                tags=f.tags or "",
            ))

    return sorted(results, key=lambda x: x.score, reverse=True)[:req.limit]

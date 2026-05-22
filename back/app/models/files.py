import uuid
from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field, Relationship
from .projects import Projects


# [DB 테이블 모델]
class Files(SQLModel, table=True):
    __tablename__ = "files"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)

    # 외래키
    project_id: str = Field(foreign_key="projects.id", ondelete="CASCADE", index=True)

    # 필드
    title: Optional[str] = None
    tags: Optional[str] = None
    icon: Optional[str] = None
    prompt: Optional[str] = None
    content: Optional[str] = None
    summary: Optional[str] = None
    graph: Optional[str] = None
    memo: Optional[str] = None
    create_at: datetime
    update_at: Optional[datetime] = None

    # 관계 설정
    projects: Optional[Projects] = Relationship(back_populates="files")


# [요청 모델]
class FileCreate(SQLModel):
    id: Optional[str] = None
    project_id: str
    title: Optional[str] = None
    tags: Optional[str] = None
    icon: Optional[str] = None
    prompt: Optional[str] = None
    content: Optional[str] = None
    summary: Optional[str] = None
    graph: Optional[str] = None
    memo: Optional[str] = None
    create_at: datetime
    update_at: Optional[datetime] = None


# [응답 모델]
class FileRead(SQLModel):
    id: str
    project_id: str
    title: Optional[str] = None
    tags: Optional[str] = None
    icon: Optional[str] = None
    prompt: Optional[str] = None
    content: Optional[str] = None
    summary: Optional[str] = None
    graph: Optional[str] = None
    memo: Optional[str] = None
    create_at: datetime
    update_at: Optional[datetime] = None

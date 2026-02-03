import uuid
from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field, Relationship
from .projects import Projects


# [DB 테이블 모델]
class Files(SQLModel, table=True):
    __tablename__ = "files"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)

    # 외래키
    project_id: uuid.UUID = Field(foreign_key="projects.id", ondelete="CASCADE")

    # 필드
    title: Optional[str] = None
    tags: Optional[str] = None
    icon: Optional[str] = None
    prompt: Optional[str] = None
    content: Optional[str] = None
    summary: Optional[str] = None
    create_at: datetime
    update_at: Optional[datetime] = None

    # 관계 설정
    projects: Optional[Projects] = Relationship(back_populates="files")


# [요청 모델]
class FileCreate(SQLModel):
    id: Optional[uuid.UUID] = None
    project_id: uuid.UUID
    title: Optional[str] = None
    tags: Optional[str] = None
    icon: Optional[str] = None
    prompt: Optional[str] = None
    content: Optional[str] = None
    summary: Optional[str] = None
    create_at: datetime
    update_at: Optional[datetime] = None


# [응답 모델]
class FileRead(SQLModel):
    id: uuid.UUID
    project_id: uuid.UUID
    title: Optional[str] = None
    tags: Optional[str] = None
    icon: Optional[str] = None
    prompt: Optional[str] = None
    content: Optional[str] = None
    summary: Optional[str] = None
    create_at: datetime
    update_at: Optional[datetime] = None
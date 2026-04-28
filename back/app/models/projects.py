import uuid
from datetime import datetime
from typing import Optional, List
from sqlmodel import SQLModel, Field, Relationship
from .users import Users


# [DB 테이블 모델]
class Projects(SQLModel, table=True):
    __tablename__ = "projects"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)

    # 외래키 — user_id 는 Firebase UID(str)
    user_id: str = Field(foreign_key="users.id", ondelete="CASCADE", index=True)

    # 필드
    create_at: datetime
    update_at: datetime
    name: str = Field(index=True)
    tags: Optional[str] = None
    icon: Optional[str] = None
    is_sync: bool = Field(default=False)

    # 관계 설정
    user: Optional[Users] = Relationship(back_populates="projects")
    files: List["Files"] = Relationship(back_populates="projects")


# [요청 모델]
class ProjectCreate(SQLModel):
    id: Optional[str] = None
    user_id: str
    create_at: datetime
    update_at: datetime
    name: str
    tags: Optional[str] = None
    icon: Optional[str] = None
    is_sync: bool = False


# [응답 모델]
class ProjectRead(SQLModel):
    id: str
    user_id: str
    create_at: datetime
    update_at: datetime
    name: str
    tags: Optional[str] = None
    icon: Optional[str] = None
    is_sync: bool

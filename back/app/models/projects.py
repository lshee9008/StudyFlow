import uuid
from datetime import datetime
from typing import Optional, List
from sqlmodel import SQLModel, Field, Relationship
# 순환 참조 방지를 위해 TYPE_CHECKING을 쓸 수도 있지만, 여기선 간단히 문자열 참조 사용
from .users import Users


# [DB 테이블 모델]
class Projects(SQLModel, table=True):
    __tablename__ = "projects"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)

    # 외래키
    user_id: uuid.UUID = Field(foreign_key="users.id", ondelete="CASCADE")

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
    id: Optional[uuid.UUID] = None
    user_id: uuid.UUID
    create_at: datetime
    update_at: datetime
    name: str
    tags: Optional[str] = None
    icon: Optional[str] = None
    is_sync: bool = False

# [응답 모델]
class ProjectRead(SQLModel):
    id: uuid.UUID
    user_id: uuid.UUID
    create_at: datetime
    update_at: datetime
    name: str
    tags: Optional[str] = None
    icon: Optional[str] = None
    is_sync: bool

from typing import Optional, List
from sqlmodel import SQLModel, Field, Relationship


# [DB 테이블 모델]
class Users(SQLModel, table=True):
    __tablename__ = "users"

    # 기본키 — Firebase UID(str) 또는 UUID(str) 모두 수용
    id: str = Field(primary_key=True)

    # 일반 필드
    name: str = Field(index=True, max_length=64)
    join_path: str = Field(index=True)
    social_id: Optional[str] = Field(default=None, index=True)
    password: Optional[str] = Field(default=None)

    # 관계 설정 (Users <-> Projects)
    projects: List["Projects"] = Relationship(back_populates="user")


# [요청 모델] 회원가입 시 받는 데이터
class UserCreate(SQLModel):
    id: Optional[str] = None     # Firebase UID 또는 클라이언트 생성 UUID
    name: str
    join_path: str
    social_id: Optional[str] = None
    password: Optional[str] = None


# [응답 모델] 클라이언트에게 돌려줄 데이터 (비밀번호 제외)
class UserRead(SQLModel):
    id: str
    name: str
    join_path: str
    social_id: Optional[str] = None

from sqlmodel import SQLModel, Field, Relationship
from typing import List, Optional
from datetime import datetime
import uuid
from sqlalchemy import Column, Text  # 긴 텍스트 저장을 위해 필수


# --- 폴더 (프로젝트) 모델 ---
class Folder(SQLModel, table=True):
    __tablename__ = "folders"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    name: str = Field(index=True)
    parent_id: Optional[uuid.UUID] = Field(default=None, foreign_key="folders.id")
    created_at: datetime = Field(default_factory=datetime.utcnow)

    # Relationship: 폴더는 여러 개의 노트를 가짐
    notes: List["Note"] = Relationship(back_populates="folder")


# --- 노트 (파일) 모델 ---
class Note(SQLModel, table=True):
    __tablename__ = "notes"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    folder_id: Optional[uuid.UUID] = Field(default=None, foreign_key="folders.id")
    title: str

    # [중요] VARCHAR(255) 제한을 피하기 위해 Text 타입 적용
    content_raw: Optional[str] = Field(default="", sa_column=Column(Text))
    content_summary: Optional[str] = Field(default="", sa_column=Column(Text))

    tags: Optional[str] = Field(default=None)  # 태그는 쉼표로 구분된 문자열(JSON string) 권장
    is_pinned: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    # Relationship: 노트는 하나의 폴더에 속함
    folder: Optional[Folder] = Relationship(back_populates="notes")
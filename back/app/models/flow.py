"""
학습 흐름 추적 모델
- QuizAttempt : 퀴즈 응시 기록
- ReviewSchedule: 간격 반복 복습 스케줄 (SM-2 알고리즘)
"""
import uuid
from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field


# ── 퀴즈 응시 기록 ──────────────────────────────────────────────
class QuizAttempt(SQLModel, table=True):
    __tablename__ = "quiz_attempts"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(index=True)
    file_id: str = Field(index=True)
    project_id: str = Field(index=True)
    score: int          # 맞은 수
    total: int          # 전체 문제 수
    created_at: datetime = Field(default_factory=datetime.utcnow)


class QuizAttemptCreate(SQLModel):
    user_id: str
    file_id: str
    project_id: str
    score: int
    total: int


class QuizAttemptRead(SQLModel):
    id: str
    user_id: str
    file_id: str
    project_id: str
    score: int
    total: int
    created_at: datetime


# ── 복습 스케줄 (SM-2 기반 간격 반복) ─────────────────────────────
class ReviewSchedule(SQLModel, table=True):
    __tablename__ = "review_schedules"

    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(index=True)
    file_id: str = Field(index=True)
    file_title: Optional[str] = None

    # SM-2 알고리즘 파라미터
    review_count: int = 0           # 복습 횟수
    ease_factor: float = 2.5        # 난이도 계수 (2.5 기본)
    interval_days: int = 1          # 다음 복습까지 일수

    last_reviewed_at: Optional[datetime] = None
    next_review_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

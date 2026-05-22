import os
from sqlalchemy import inspect, text
from sqlmodel import SQLModel, create_engine, Session
from .config import settings

# 테이블 생성을 위해 모든 모델을 임포트 (SQLModel.metadata에 등록)
from app.models import users, projects, files, flow  # noqa: F401

# check_same_thread는 SQLite에서만 필요. PostgreSQL 사용 시 connect_args={} 로 변경
connect_args = {"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {}

engine = create_engine(settings.DATABASE_URL, echo=True, connect_args=connect_args)

def init_db():
    # DB_RESET=true 환경변수가 설정되면 기존 테이블을 모두 삭제 후 재생성 (UUID→str 마이그레이션용)
    if os.getenv("DB_RESET", "").lower() == "true":
        SQLModel.metadata.drop_all(engine)

    SQLModel.metadata.create_all(engine)
    inspector = inspect(engine)
    try:
        columns = {column["name"] for column in inspector.get_columns("files")}
    except Exception:
        columns = set()
    try:
        project_columns = {
            column["name"] for column in inspector.get_columns("projects")
        }
    except Exception:
        project_columns = set()

    if columns and "graph" not in columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE files ADD COLUMN graph TEXT"))
    if columns and "memo" not in columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE files ADD COLUMN memo TEXT"))
    if project_columns and "icon" not in project_columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE projects ADD COLUMN icon TEXT"))

def get_session():
    with Session(engine) as session:
        yield session

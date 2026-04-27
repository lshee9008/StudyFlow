from sqlalchemy import inspect, text
from sqlmodel import SQLModel, create_engine, Session
from .config import settings

# check_same_thread는 SQLite에서만 필요. PostgreSQL 사용 시 connect_args={} 로 변경
connect_args = {"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {}

engine = create_engine(settings.DATABASE_URL, echo=True, connect_args=connect_args)

def init_db():
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
    if project_columns and "icon" not in project_columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE projects ADD COLUMN icon TEXT"))

def get_session():
    with Session(engine) as session:
        yield session

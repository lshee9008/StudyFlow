from sqlmodel import SQLModel, create_engine, Session
import os
from dotenv import load_dotenv

load_dotenv()

# .env가 없거나 설정이 안 되어 있을 경우를 대비한 SQLite 백업 경로
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./note_db.db")

# echo=True는 SQL 쿼리 로그를 보여줍니다. 배포 시 False로 변경하세요.
engine = create_engine(DATABASE_URL, echo=True)

def get_session():
    with Session(engine) as session:
        yield session

# ▼ 지난번 에러의 원인이었던 함수입니다. 필수 포함! ▼
def init_db():
    SQLModel.metadata.create_all(engine)
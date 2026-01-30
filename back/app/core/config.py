import os

class Settings:
    PROJECT_NAME: str = "StudyFlow API"
    # 실제 운영 시 .env 파일이나 환경변수에서 가져오도록 수정 권장
    # 예: postgresql://user:password@localhost:5432/dbname
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./studyflow.db")

settings = Settings()
import os

class Settings:
    PROJECT_NAME: str = "StudyFlow API"

    # ── Database ────────────────────────────────────────────
    # local  : sqlite:///./studyflow.db
    # render : postgresql://user:pw@host/db  (자동 주입)
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./studyflow.db").replace("postgres://", "postgresql://", 1)

    # ── Redis ───────────────────────────────────────────────
    # local  : redis://localhost:6379/0
    # render : redis://red-xxx:6379  (자동 주입)
    # 미설정 시 in-memory LRU 폴백 자동 사용
    REDIS_URL: str = os.getenv("REDIS_URL", "")

    # ── Google Gemini (LLM) ─────────────────────────────────
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")

    # ── External APIs ───────────────────────────────────────
    TAVILY_API_KEY: str = os.getenv("TAVILY_API_KEY", "")

    # ── CORS ────────────────────────────────────────────────
    # 쉼표로 여러 오리진 지정: https://app.vercel.app,https://custom.com
    ALLOWED_ORIGINS: str = os.getenv("ALLOWED_ORIGINS", "*")

settings = Settings()

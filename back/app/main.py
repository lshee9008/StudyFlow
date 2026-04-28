import uvicorn
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.api import api_router
from app.core.config import settings
from app.core.database import init_db
from app.core.redis_cache import init_redis, close_redis


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── startup ──────────────────────────────────────────
    init_db()           # DB 테이블 생성 / 마이그레이션
    await init_redis()  # Redis 연결 (실패 시 인메모리 폴백)
    yield
    # ── shutdown ─────────────────────────────────────────
    await close_redis()


app = FastAPI(title="StudyFlow API", version="1.0.0", lifespan=lifespan)

# CORS — 환경변수 ALLOWED_ORIGINS 로 제어 (쉼표 구분 다중 오리진)
_origins = (
    [o.strip() for o in settings.ALLOWED_ORIGINS.split(",")]
    if settings.ALLOWED_ORIGINS != "*"
    else ["*"]
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api")


@app.get("/")
@app.head("/")
def root():
    return {"status": "ok", "service": settings.PROJECT_NAME}


@app.get("/health")
@app.head("/health")
def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)


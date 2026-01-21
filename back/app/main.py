from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import redis
import os

# 내부 모듈 임포트
from .core.database import init_db
from .routers import project_router
from .routers import project_router, ai_router

app = FastAPI(title="Note App API", version="1.0.0")

# --- CORS 설정 (Flutter 앱 연동을 위해 필수) ---
origins = [
    "http://localhost",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "*"  # 개발 단계에서는 모든 출처 허용
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Redis 연결 ---
try:
    redis_client = redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379/0"))
except Exception as e:
    print(f"Redis Connection Warning: {e}")
    redis_client = None

# --- 서버 시작 시 실행 ---
@app.on_event("startup")
def on_startup():
    # DB 테이블 자동 생성
    init_db()

# --- 라우터 등록 ---
app.include_router(project_router.router)
app.include_router(project_router.router)
app.include_router(ai_router.router) # 라우터 등록

@app.get("/")
def health_check():
    return {"status": "ok", "message": "Server is running correctly."}
from fastapi import APIRouter
from app.api.endpoints import users, projects, files, ai # ai 추가

api_router = APIRouter()
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(projects.router, prefix="/projects", tags=["projects"])
api_router.include_router(files.router, prefix="/files", tags=["files"])
# 🚨 AI 라우터 추가
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])
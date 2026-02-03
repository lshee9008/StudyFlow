import uvicorn
from fastapi import FastAPI
from app.api.api import api_router
from app.core.database import init_db

app = FastAPI(title="StudyFlow Backend")

@app.on_event("startup")
def on_startup():
    init_db()  # DB 테이블 생성

app.include_router(api_router, prefix="/api")

@app.get("/")
def root():
    return {"message": "Server is running!"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

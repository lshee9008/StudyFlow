import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
from app.core.database import get_session
from app.models.users import UserCreate, UserRead, Users
from app.crud import crud_user

router = APIRouter()


@router.post("/", response_model=UserCreate)
def create_user(
        *,
        session: Session = Depends(get_session),
        user_in: UserCreate
):
    print(f"📥 Received Data: {user_in}")
    return crud_user.create_user(session, user_in)


# 💡 [추가 완료] 프론트엔드에서 유저 정보를 조회할 수 있도록 GET 엔드포인트 추가
@router.get("/{user_id}", response_model=UserRead)
def read_user(
    *,
    session: Session = Depends(get_session),
    user_id: uuid.UUID
):
    user = session.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
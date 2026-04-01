import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select          # ← select 추가
from pydantic import BaseModel                # ← 추가
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


from sqlmodel import select


class LoginRequest(BaseModel):
    name: str
    password: str


@router.post("/login")
def login_user(
        *,
        session: Session = Depends(get_session),
        login_in: LoginRequest
):
    statement = select(Users).where(Users.name == login_in.name)
    user = session.exec(statement).first()

    if not user:
        raise HTTPException(status_code=400, detail="존재하지 않는 아이디입니다.")
    if user.password != login_in.password:
        raise HTTPException(status_code=400, detail="비밀번호가 틀렸습니다.")

    return user
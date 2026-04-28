from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from pydantic import BaseModel
from typing import Optional

from app.core.database import get_session
from app.models.users import UserCreate, UserRead, Users
from app.crud import crud_user

router = APIRouter()


# ── 회원가입 ──────────────────────────────────────────────
@router.post("/", response_model=UserRead)
def create_user(*, session: Session = Depends(get_session), user_in: UserCreate):
    # id 중복 체크 (Firebase UID 재가입 방지)
    if user_in.id:
        existing_by_id = session.get(Users, user_in.id)
        if existing_by_id:
            return existing_by_id  # 이미 존재하면 그냥 반환
    return crud_user.create_user(session, user_in)


# ── 유저 조회 ──────────────────────────────────────────────
@router.get("/{user_id}", response_model=UserRead)
def read_user(*, session: Session = Depends(get_session), user_id: str):
    user = session.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ── 로그인 ────────────────────────────────────────────────
class LoginRequest(BaseModel):
    name: str
    password: str

@router.post("/login", response_model=UserRead)
def login_user(*, session: Session = Depends(get_session), login_in: LoginRequest):
    user = session.exec(select(Users).where(Users.name == login_in.name)).first()
    if not user:
        raise HTTPException(status_code=400, detail="존재하지 않는 아이디입니다.")
    if user.password != login_in.password:
        raise HTTPException(status_code=400, detail="비밀번호가 올바르지 않습니다.")
    return user


# ── 정보 수정 ──────────────────────────────────────────────
class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    password: Optional[str] = None

@router.put("/{user_id}", response_model=UserRead)
def update_user(
    user_id: str,
    user_in: UserUpdateRequest,
    session: Session = Depends(get_session)
):
    user = session.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user_in.name:
        # 이름 중복 체크 (자기 자신 제외)
        dup = session.exec(select(Users).where(Users.name == user_in.name)).first()
        if dup and dup.id != user_id:
            raise HTTPException(status_code=400, detail="이미 사용 중인 이름입니다.")
        user.name = user_in.name

    if user_in.password is not None:
        user.password = user_in.password

    session.add(user)
    session.commit()
    session.refresh(user)
    return user


# ── 탈퇴 ─────────────────────────────────────────────────
@router.delete("/{user_id}")
def delete_user(*, session: Session = Depends(get_session), user_id: str):
    user = session.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    session.delete(user)
    session.commit()
    return {"message": "User deleted successfully"}

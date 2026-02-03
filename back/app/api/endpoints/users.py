from fastapi import APIRouter, Depends
from sqlmodel import Session
from app.core.database import get_session
from app.models.users import UserCreate, UserRead
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
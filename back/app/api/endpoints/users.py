from fastapi import APIRouter, Depends
from sqlmodel import Session
from app.core.database import get_session
from app.models.users import UserCreate, UserRead
from app.crud import crud_user

router = APIRouter()


# 1. HTTP POST 메서드 정의
#    - 클라이언트가 이 주소로 데이터를 보낼 때 실행됩니다.
#    - response_model=UserRead: 중요! 함수가 리턴하는 데이터(Users 객체)에서
#      'UserRead' 모델에 정의된 필드만 걸러서 응답합니다. (즉, 비밀번호 필드 자동 제외)
@router.post("/", response_model=UserRead)
def create_user(
        *,
        # 2. DB 세션 주입 (Dependency Injection)
        #    - 요청이 들어올 때마다 DB 연결(Session)을 생성하고,
        #    - 요청 처리가 끝나면 자동으로 세션을 닫아줍니다.
        session: Session = Depends(get_session),

        # 3. Request Body (요청 본문)
        #    - 클라이언트가 보낸 JSON 데이터가 'UserCreate' 모델 형식(타입, 길이 등)에
        #      맞는지 자동으로 검증(Validation)합니다.
        #    - 틀리면 FastAPI가 알아서 422 에러를 보냅니다.
        user_in: UserCreate
):
    """
    [유저 생성 API]
    클라이언트로부터 받은 정보(user_in)를 DB에 저장하고,
    저장된 정보를 반환합니다.
    """

    # 4. 비즈니스 로직(CRUD) 호출
    #    - 실제 DB에 Insert 하는 작업은 crud_user 파일에 위임합니다.
    return crud_user.create_user(session, user_in)
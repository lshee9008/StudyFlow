from sqlmodel import Session
from app.models.users import Users, UserCreate

def create_user(session: Session, user_in: UserCreate) -> Users:
    # 1. 변환: 클라이언트가 보낸 데이터(user_in)를 DB 테이블 형태(Users)로 바꿉니다.
    db_obj = Users.model_validate(user_in)

    # 2. 주입 (Injection): 여기가 바로 질문하신 부분입니다!
    #    세션(장바구니)에 데이터를 담습니다. 아직 DB에 들어가진 않았습니다.
    session.add(db_obj)

    # 3. 저장 (Save): "이제 진짜 저장해!"라고 명령합니다.
    #    이때 실제로 SQL(INSERT INTO users...)이 실행됩니다.
    session.commit()

    # 4. 새로고침: DB에 저장되면서 생성된 id나 default 값을 다시 가져옵니다.
    session.refresh(db_obj)

    return db_obj
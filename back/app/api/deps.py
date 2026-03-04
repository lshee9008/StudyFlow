from typing import Generator, Any
from sqlmodel import Session
from app.core.database import get_session
import uuid

# 1. get_db 해결: get_session을 그대로 가져와서 이름만 맞춰줍니다.
get_db = get_session

# 2. get_current_active_user 해결 (임시 통과용)
# 로그인 기능이 완성되기 전까지, 모든 요청을 '임시 관리자'가 보낸 것으로 처리합니다.
class MockUser:
    def __init__(self):
        # 에러 로그에 있던 UUID를 사용하여, 기존 데이터와 충돌을 줄입니다.
        # 실제 DB 사용자 테이블에 이 UUID를 가진 유저가 없으면 FK 에러가 날 수 있습니다.
        # 그럴 땐 DB를 초기화하거나, 아무 유저나 하나 생성 후 그 ID를 넣으면 됩니다.
        self.id = uuid.UUID("66e5dc5c-4282-4277-8af4-1881e3bc2613")
        self.email = "admin@studyflow.com"
        self.is_active = True

def get_current_active_user() -> Any:
    """
    JWT 토큰 검증 없이 무조건 MockUser를 리턴합니다.
    개발 단계에서 로그인 없이 API를 테스트하기 위함입니다.
    """
    return MockUser()
from sqlmodel import Session, select
import uuid
# ⚠️ 중요: Projects, ProjectCreate가 정의된 실제 경로로 import 해야 합니다.
# 만약 app.schemas.project 에 있다면 거기로 수정해주세요.
from app.models.projects import Projects, ProjectCreate


# [수정 1] 인자에 obj_in, user_id 추가
def create_project(session: Session, obj_in: ProjectCreate, user_id: uuid.UUID) -> Projects:
    # 1. Pydantic 모델(obj_in)을 DB 모델(Projects)로 변환
    db_obj = Projects.model_validate(obj_in)

    # 2. 현재 로그인한 사용자 ID 주입 (DB에 저장하기 위해)
    # 모델 필드명이 owner_id라면 db_obj.owner_id = user_id 로 변경해야 합니다.
    db_obj.user_id = user_id

    session.add(db_obj)
    session.commit()
    session.refresh(db_obj)
    return db_obj




def get_projects_by_user(session: Session, user_id: uuid.UUID):
    # 모델 필드명이 owner_id라면 Projects.owner_id == user_id 로 변경
    statement = select(Projects).where(Projects.user_id == user_id)
    return session.exec(statement).all()


# [추가] 상세 조회 (endpoints에서 사용됨)
def get_project(session: Session, project_id: str) -> Projects | None:
    return session.get(Projects, project_id)


# [추가] 삭제 (endpoints에서 사용됨)
def remove_project(session: Session, project_id: str) -> Projects:
    project = session.get(Projects, project_id)
    if project:
        session.delete(project)
        session.commit()
    return project
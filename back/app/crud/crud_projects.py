from sqlmodel import Session, select
import uuid

# ⚠️ 실제 프로젝트 구조에 맞게 경로 확인
from app.models.projects import Projects, ProjectCreate

def create_project(session: Session, obj_in: ProjectCreate, user_id: uuid.UUID) -> Projects:
    db_obj = Projects.model_validate(obj_in)
    db_obj.user_id = user_id
    session.add(db_obj)
    session.commit()
    session.refresh(db_obj)
    return db_obj

def get_projects_by_user(session: Session, user_id: uuid.UUID):
    statement = select(Projects).where(Projects.user_id == user_id)
    return session.exec(statement).all()

# 🚨 [수정] project_id 타입을 str -> uuid.UUID 로 변경
def get_project(session: Session, project_id: uuid.UUID) -> Projects | None:
    return session.get(Projects, project_id)

# 🚨 [수정] project_id 타입을 str -> uuid.UUID 로 변경
def remove_project(session: Session, project_id: uuid.UUID) -> Projects | None:
    project = session.get(Projects, project_id)
    if project:
        session.delete(project)
        session.commit()
    return project
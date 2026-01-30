from sqlmodel import Session, select
from app.models.project import Projects, ProjectCreate
import uuid

def create_project(session: Session, project_in: ProjectCreate) -> Projects:
    db_obj = Projects.model_validate(project_in)
    session.add(db_obj)
    session.commit()
    session.refresh(db_obj)
    return db_obj

def get_projects_by_user(session: Session, user_id: uuid.UUID):
    statement = select(Projects).where(Projects.user_id == user_id)
    return session.exec(statement).all()
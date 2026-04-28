from sqlmodel import Session, select

from app.models.projects import Projects, ProjectCreate


def create_project(session: Session, obj_in: ProjectCreate, user_id: str) -> Projects:
    db_obj = Projects.model_validate(obj_in)
    db_obj.user_id = user_id
    session.add(db_obj)
    session.commit()
    session.refresh(db_obj)
    return db_obj


def get_projects_by_user(session: Session, user_id: str):
    statement = select(Projects).where(Projects.user_id == user_id)
    return session.exec(statement).all()


def get_project(session: Session, project_id: str) -> Projects | None:
    return session.get(Projects, project_id)


def remove_project(session: Session, project_id: str) -> Projects | None:
    project = session.get(Projects, project_id)
    if project:
        session.delete(project)
        session.commit()
    return project

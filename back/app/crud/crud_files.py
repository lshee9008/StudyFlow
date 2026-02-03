from sqlmodel import Session, select
from app.models.files import Files, FileCreate
import uuid

def create_file(session: Session, file_in: FileCreate) -> Files:
    db_obj = Files.model_validate(file_in)
    session.add(db_obj)
    session.commit()
    session.refresh(db_obj)
    return db_obj

def get_files_by_project(session: Session, project_id: uuid.UUID):
    statement = select(Files).where(Files.project_id == project_id)
    return session.exec(statement).all()
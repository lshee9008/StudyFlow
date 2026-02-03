from typing import List
from fastapi import APIRouter, Depends
from sqlmodel import Session
from app.core.database import get_session
from app.models.projects import ProjectCreate, ProjectRead
from app.crud import crud_projects
import uuid

router = APIRouter()

@router.post("/", response_model=ProjectRead)
def create_project(
    *, session: Session = Depends(get_session), project_in: ProjectCreate
):
    return crud_project.create_project(session, project_in)

@router.get("/{user_id}", response_model=List[ProjectRead])
def read_projects(
    user_id: uuid.UUID, session: Session = Depends(get_session)
):
    return crud_project.get_projects_by_user(session, user_id)
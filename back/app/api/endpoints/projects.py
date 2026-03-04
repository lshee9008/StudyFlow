from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session

from app.api import deps

# 🚨 [수정 완료] 실제 파일명(crud_projects.py)에 맞춰 import 경로 수정
from app.crud import crud_projects

# Schemas import
from app.models.projects import ProjectCreate, ProjectRead

router = APIRouter()

@router.post("/", response_model=ProjectRead)
def create_project(
    *,
    session: Session = Depends(deps.get_db),
    project_in: ProjectCreate,
    current_user: Any = Depends(deps.get_current_active_user),
) -> Any:
    """
    Create new project.
    """
    # crud_projects 모듈 사용
    project = crud_projects.create_project(session=session, obj_in=project_in, user_id=current_user.id)
    return project

@router.get("/", response_model=List[ProjectRead])
def read_projects(
    session: Session = Depends(deps.get_db),
    current_user: Any = Depends(deps.get_current_active_user),
    skip: int = 0,
    limit: int = 100,
) -> Any:
    """
    Retrieve projects.
    """
    return crud_projects.get_projects_by_user(session=session, user_id=current_user.id)

@router.get("/{project_id}", response_model=ProjectRead)
def read_project(
    *,
    session: Session = Depends(deps.get_db),
    project_id: str,
    current_user: Any = Depends(deps.get_current_active_user),
) -> Any:
    """
    Get project by ID.
    """
    project = crud_projects.get_project(session=session, project_id=project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.owner_id != current_user.id:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    return project

@router.delete("/{project_id}", response_model=ProjectRead)
def delete_project(
    *,
    session: Session = Depends(deps.get_db),
    project_id: str,
    current_user: Any = Depends(deps.get_current_active_user),
) -> Any:
    """
    Delete an project.
    """
    project = crud_projects.get_project(session=session, project_id=project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.owner_id != current_user.id:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    project = crud_projects.remove_project(session=session, project_id=project_id)
    return project
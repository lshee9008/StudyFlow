from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session

from app.core.database import get_session
from app.models.projects import ProjectCreate, ProjectRead, Projects
from app.crud import crud_projects

router = APIRouter()

# 1. 🟢 특정 유저의 프로젝트 목록 조회
@router.get("/{user_id}", response_model=List[ProjectRead])
def read_projects(
        user_id: str,
        session: Session = Depends(get_session)
):
    projects = crud_projects.get_projects_by_user(session, user_id=user_id)
    return projects


# 2. 🟢 새 프로젝트 생성
@router.post("/", response_model=ProjectRead)
def create_project(
        *,
        session: Session = Depends(get_session),
        project_in: ProjectCreate
):
    return crud_projects.create_project(session=session, obj_in=project_in, user_id=project_in.user_id)


# 3. 🟢 프로젝트 정보 수정 (이름, 태그 등)
@router.put("/{project_id}", response_model=ProjectRead)
def update_project(
        project_id: str,
        project_in: ProjectCreate,
        session: Session = Depends(get_session)
):
    project = session.get(Projects, project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    project_data = project_in.model_dump(exclude_unset=True)
    for key, value in project_data.items():
        setattr(project, key, value)

    session.add(project)
    session.commit()
    session.refresh(project)
    return project


# 4. 🟢 프로젝트 삭제
@router.delete("/{project_id}")
def delete_project(
        *,
        session: Session = Depends(get_session),
        project_id: str
):
    project = crud_projects.remove_project(session=session, project_id=project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    return {"message": "Project deleted successfully"}

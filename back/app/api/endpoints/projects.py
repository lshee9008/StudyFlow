import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session

from app.core.database import get_session
from app.models.projects import ProjectCreate, ProjectRead, Projects
from app.crud import crud_projects

router = APIRouter()


# 1. 🟢 특정 유저의 프로젝트 목록 조회 (이 부분이 없어서 404 에러가 났습니다!)
@router.get("/{user_id}", response_model=List[ProjectRead])
def read_projects(
        user_id: uuid.UUID,
        session: Session = Depends(get_session)
):
    # 유저의 프로젝트를 DB에서 조회
    projects = crud_projects.get_projects_by_user(session, user_id=user_id)

    # 💡 [중요] 프로젝트가 하나도 없어도 404 에러를 내지 않고 빈 리스트([])를 200 OK로 반환해야 합니다.
    return projects


# 2. 🟢 새 프로젝트 생성
@router.post("/", response_model=ProjectRead)
def create_project(
        *,
        session: Session = Depends(get_session),
        project_in: ProjectCreate
):
    # crud_projects의 create_project 함수 호출
    return crud_projects.create_project(session=session, obj_in=project_in, user_id=project_in.user_id)


# 3. 🟢 프로젝트 정보 수정 (이름, 태그 등)
@router.put("/{project_id}", response_model=ProjectRead)
def update_project(
        project_id: uuid.UUID,
        project_in: ProjectCreate,
        session: Session = Depends(get_session)
):
    project = session.get(Projects, project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    # 전달받은 데이터로 업데이트
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
        project_id: uuid.UUID
):
    project = crud_projects.remove_project(session=session, project_id=project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    return {"message": "Project deleted successfully"}
from typing import List
from fastapi import APIRouter, Depends
from sqlmodel import Session
from app.core.database import get_session
from app.models.file import FileCreate, FileRead
from app.crud import crud_file
import uuid

router = APIRouter()

@router.post("/", response_model=FileRead)
def create_file(
    *, session: Session = Depends(get_session), file_in: FileCreate
):
    return crud_file.create_file(session, file_in)

@router.get("/{project_id}", response_model=List[FileRead])
def read_files(
    project_id: uuid.UUID, session: Session = Depends(get_session)
):
    return crud_file.get_files_by_project(session, project_id)

# 서버에서 대충 uuid로 userid 할당되게끔만 로그인 서비스는 늦어질 수도 있으니 이정도만 되게끔 해주고 메인푸시
# 파일 작업 하고 너는 로그인/홈/프로젝트 작업 하고!!!
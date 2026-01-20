from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select
from typing import List
import uuid

from ..core.database import get_session
from ..models.models import Folder, Note

router = APIRouter(prefix="/api", tags=["projects"])

# --- 프로젝트(폴더) 관련 API ---

@router.post("/projects/", response_model=Folder)
def create_project(folder: Folder, session: Session = Depends(get_session)):
    session.add(folder)
    session.commit()
    session.refresh(folder)
    return folder

@router.get("/projects/", response_model=List[Folder])
def read_projects(session: Session = Depends(get_session)):
    # 최신순 정렬
    statement = select(Folder).order_by(Folder.created_at.desc())
    results = session.exec(statement).all()
    return results

# --- 노트(파일) 관련 API ---

@router.post("/notes/", response_model=Note)
def create_note(note: Note, session: Session = Depends(get_session)):
    session.add(note)
    session.commit()
    session.refresh(note)
    return note

@router.get("/projects/{folder_id}/notes", response_model=List[Note])
def read_notes_by_project(folder_id: uuid.UUID, session: Session = Depends(get_session)):
    statement = select(Note).where(Note.folder_id == folder_id).order_by(Note.created_at.desc())
    results = session.exec(statement).all()
    return results
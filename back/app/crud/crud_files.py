from sqlmodel import Session, select
from app.models.files import Files, FileCreate
from app.core.vector_store import get_vector_store
import langchain_core.documents


def create_file(session: Session, file_in: FileCreate) -> Files:
    # 1. DB 저장
    db_obj = Files.model_validate(file_in)
    session.add(db_obj)
    session.commit()
    session.refresh(db_obj)

    # 2. [RAG] 벡터 DB에 문서 추가
    if db_obj.content and db_obj.content.strip():
        try:
            vector_store = get_vector_store()
            doc = langchain_core.documents.Document(
                page_content=db_obj.content,
                metadata={
                    "file_id": str(db_obj.id),
                    "project_id": str(db_obj.project_id),
                    "title": db_obj.title or "무제"
                }
            )
            vector_store.add_documents([doc])
            print(f"✅ [RAG] File {db_obj.id} embedded successfully.")
        except Exception as e:
            print(f"❌ [RAG Error] Embedding failed: {e}")

    return db_obj


def get_files_by_project(session: Session, project_id: str):
    statement = select(Files).where(Files.project_id == project_id)
    return session.exec(statement).all()

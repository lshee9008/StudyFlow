import os
from langchain_community.vectorstores import Chroma
from langchain_huggingface import HuggingFaceEmbeddings

# 한국어 성능이 우수한 경량화 임베딩 모델 (Local)
MODEL_NAME = "jhgan/ko-sbert-nli"
PERSIST_DIRECTORY = "./chroma_db"


def get_vector_store():
    # 임베딩 모델 로드
    embeddings = HuggingFaceEmbeddings(
        model_name=MODEL_NAME,
        model_kwargs={'device': 'cpu'},  # GPU가 있다면 'cuda'
        encode_kwargs={'normalize_embeddings': True}
    )

    # ChromaDB 로드 (없으면 생성)
    vector_store = Chroma(
        persist_directory=PERSIST_DIRECTORY,
        embedding_function=embeddings,
        collection_name="studyflow_notes"
    )
    return vector_store
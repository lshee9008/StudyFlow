<div align="center">

# 📚 StudyFlow

### AI 기반 올인원 학습 노트 관리 플랫폼

Notion 스타일 블록 에디터에 **AI 요약 · RAG 시맨틱 검색 · QA 챗봇 · 마인드맵 시각화** 를 결합한 학생 맞춤형 학습 워크스페이스

![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.10-3776AB?logo=python&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-CI%2FCD-2496ED?logo=docker&logoColor=white)
![License](https://img.shields.io/badge/License-Proprietary-red)

</div>

---

## 📖 프로젝트 소개

**StudyFlow** 는 학생의 학습 효율을 극대화하기 위해 설계된 통합 학습 관리 플랫폼입니다.
노트 작성, 자료 검색, AI 활용이 각기 다른 도구에서 단절되던 기존 학습 흐름을 하나의 워크스페이스로 통합합니다.

Notion과 같은 블록 기반 편집기에 **AI 자동 요약**, **의미론적 검색(RAG)**, **QA 챗봇**, **마인드맵 시각화** 기능을 결합하여
학습 자료의 **작성 → 관리 → 복습** 전 과정을 한 곳에서 처리할 수 있습니다.

---

## ✨ 주요 기능

| 기능 | 설명 |
|------|------|
| 📝 **블록 에디터** | 텍스트·제목·표·코드·인용·체크박스 등 Notion 스타일 블록 편집. 슬래시(`/`) 메뉴, 인라인 서식, Undo/Redo 지원 |
| 🧮 **LaTeX 수식** | `flutter_math_fork` 기반 블록 수식(`$$`) 및 인라인 수식(`$...$`) 렌더링 |
| 🤖 **AI 요약** | Google Gemini 기반 노트 자동 요약 (핵심 개념·상세 내용·핵심 정리 구조). 커스텀 프롬프트 및 스트리밍 출력 지원 |
| 💬 **QA 챗봇** | 노트 컨텍스트 기반 질의응답. 채팅 말풍선 UI + 날짜·시간 히스토리 보존 |
| 🔍 **RAG 시맨틱 검색** | ChromaDB + LangChain 임베딩 기반 의미 검색. 키워드 매칭 폴백 |
| 🧠 **마인드맵 / 그래프** | 노트 내용 자동 마인드맵 생성, 파일 간 관계 그래프 시각화, PDF 내보내기 |
| 🖼️ **파일 첨부** | 이미지 드래그앤드롭 / 파일 선택 업로드(base64), PDF 첨부. 이미지를 AI 요약 컨텍스트에 반영 |
| ✍️ **글 교정** | 학술·캐주얼·격식 문체별 맞춤법·문법 교정 |

---

## 🛠️ 기술 스택

### Frontend
- **Flutter Web** (Dart)
- **Riverpod** — 상태 관리
- **flutter_markdown**, **flutter_math_fork** — 마크다운 / 수식 렌더링
- **file_picker**, **desktop_drop** — 파일 업로드
- **pdf**, **printing** — 마인드맵 PDF 내보내기
- **Firebase Auth**, **google_sign_in** — 인증

### Backend
- **FastAPI** (Python 3.10) + **Uvicorn**
- **SQLModel** — ORM / PostgreSQL · SQLite
- **Redis** — 캐시 (인메모리 폴백 지원)

### AI / ML
- **Google Gemini API** — 요약 · QA · 교정
- **LangChain** + **ChromaDB** — RAG 벡터 검색
- **sentence-transformers** — 임베딩

### DevOps
- **Docker** / **Docker Compose**
- **Render** (Cloud) — CI/CD 자동 배포

---

## 📂 프로젝트 구조

```
StudyFlow/
├── back/                       # FastAPI 백엔드
│   ├── app/
│   │   ├── main.py             # 앱 엔트리포인트
│   │   ├── api/
│   │   │   ├── api.py          # 라우터 통합
│   │   │   └── endpoints/      # users · projects · files · ai · search · flow
│   │   ├── core/               # config · database · redis · vector_store · web_search
│   │   ├── crud/               # DB CRUD 로직
│   │   └── models/             # SQLModel 데이터 모델
│   ├── Dockerfile
│   └── requirements.txt
│
├── front/study_flow/           # Flutter Web 프론트엔드
│   ├── lib/
│   │   ├── features/           # file · shell 등 기능별 모듈
│   │   └── models/             # block_model 등 데이터 모델
│   └── pubspec.yaml
│
├── docker-compose.yml          # 로컬 개발 전체 스택
├── render.yaml                 # 클라우드 배포 설정
└── LICENSE
```

---

## 🚀 시작하기

### 사전 요구사항
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x 이상)
- [Docker](https://www.docker.com/) & Docker Compose
- Google Gemini API Key

### 1. 백엔드 실행 (Docker)

```bash
# 환경변수 설정
cp .env.example .env        # GEMINI_API_KEY 등 입력

# 전체 스택 실행 (FastAPI + PostgreSQL + Redis)
docker compose up -d

# 로그 확인
docker compose logs -f backend
```

| 서비스 | 포트 |
|--------|------|
| FastAPI 백엔드 | `8000` |
| PostgreSQL | `5432` |
| Redis | `6379` |

API 문서: `http://localhost:8000/docs`

### 2. 백엔드 실행 (로컬, Docker 미사용)

```bash
cd back
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### 3. 프론트엔드 실행

```bash
cd front/study_flow
flutter pub get
flutter run -d chrome          # 웹 브라우저로 실행
```

웹 빌드:

```bash
flutter build web
```

---

## 🌐 API 엔드포인트

| 그룹 | Prefix | 설명 |
|------|--------|------|
| Users | `/api/users` | 회원가입 · 로그인 · 인증 |
| Projects | `/api/projects` | 프로젝트(폴더) CRUD |
| Files | `/api/files` | 노트 파일 CRUD · AI 요약 · 교정 |
| AI | `/api/ai` | AI 처리 |
| Search | `/api/search` | RAG 시맨틱 / 키워드 검색 |
| Flow | `/api/flow` | 마인드맵 · 그래프 |

헬스 체크: `GET /health`

---

## ☁️ 배포

`render.yaml` 기반으로 Render 클라우드에 배포됩니다.

```bash
# Docker 이미지 빌드 & 푸시
docker build -t lshee9008/studyflow-api:latest ./back
docker push lshee9008/studyflow-api:latest
```

- **Backend**: Render Web Service (Docker) — Singapore 리전
- **Database**: Render PostgreSQL (managed)

---

## 📄 라이선스

본 소프트웨어는 **독점 라이선스(Proprietary — All Rights Reserved)** 하에 보호됩니다.
저작권자의 명시적 서면 허가 없이 복제·배포·수정·상업적 이용·리버스 엔지니어링을 **엄격히 금지**합니다.
자세한 내용은 [LICENSE](LICENSE) 파일을 참고하세요.

문의: `seunghee0243@gmail.com`

---

<div align="center">

**© 2025–2026 StudyFlow Team. All Rights Reserved.**

</div>

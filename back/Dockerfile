# ════════════════════════════════════════════════════════════
# Stage 1 — dependency builder
#   무거운 ML 라이브러리(torch, sentence-transformers)를
#   별도 레이어에서 빌드 → 이미지 캐시 활용
# ════════════════════════════════════════════════════════════
FROM python:3.11-slim AS builder

WORKDIR /build

# 빌드 의존성 (gcc, g++: chromadb / psycopg2 컴파일용)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ git curl libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ════════════════════════════════════════════════════════════
# Stage 2 — runtime
# ════════════════════════════════════════════════════════════
FROM python:3.11-slim AS runtime

WORKDIR /app

# 런타임 의존성만 (libpq: psycopg2 런타임)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 curl \
    && rm -rf /var/lib/apt/lists/*

# Stage 1 에서 빌드한 패키지 복사
COPY --from=builder /install /usr/local

# 소스 복사 (.env, __pycache__ 등은 .dockerignore 로 제외)
COPY . .

# Render 는 $PORT 환경변수를 동적으로 주입
EXPOSE 8000

# 헬스체크 — Render 가 /health 를 polling
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

# --workers 1: ChromaDB / SQLite는 멀티프로세스 비호환 → 단일 워커
# 필요 시 PostgreSQL + stateless 구조로 변경 후 workers 늘릴 것
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]

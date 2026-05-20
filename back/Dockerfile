# ════════════════════════════════════════════════════════════
# Stage 1 — dependency builder
# ════════════════════════════════════════════════════════════
FROM python:3.11-slim AS builder

WORKDIR /build

# 빌드 의존성
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ git curl libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# pip 업그레이드 + wheel 캐시 활성화
RUN pip install --upgrade pip wheel

COPY requirements.txt .

# sentence-transformers/torch는 CPU 전용 버전으로 설치해 이미지 크기 최소화
RUN pip install --no-cache-dir --prefix=/install \
    torch --index-url https://download.pytorch.org/whl/cpu \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt


# ════════════════════════════════════════════════════════════
# Stage 2 — runtime
# ════════════════════════════════════════════════════════════
FROM python:3.11-slim AS runtime

WORKDIR /app

# 런타임 의존성
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 curl \
    && rm -rf /var/lib/apt/lists/*

# Stage 1 빌드 패키지 복사
COPY --from=builder /install /usr/local

# 소스 복사
COPY . .

EXPOSE 8000

# 헬스체크
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]

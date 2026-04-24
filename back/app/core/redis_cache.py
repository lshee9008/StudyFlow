"""
Redis 캐시 모듈
─────────────────────────────────────────────────────────────
- REDIS_URL 환경변수 설정 시 Redis 사용, 미설정 시 in-memory LRU 자동 폴백
- 연결 실패 시에도 서버가 죽지 않고 메모리 캐시로 계속 동작
- async/await 완전 지원 (redis.asyncio)
- 키 prefix: "sf:" 로 네임스페이스 분리
"""
import json
import hashlib
import logging
from collections import OrderedDict
from typing import Any, Optional

from .config import settings

logger = logging.getLogger(__name__)

# ── 전역 Redis 클라이언트 ─────────────────────────────────
_redis = None

# ── 인메모리 LRU 폴백 ─────────────────────────────────────
_mem: OrderedDict = OrderedDict()
_MEM_MAX = 200
_MEM_TTL: dict[str, float] = {}   # key → expire_epoch


# ══════════════════════════════════════════════════════════
# 수명주기
# ══════════════════════════════════════════════════════════

async def init_redis() -> None:
    """앱 startup 시 호출. Redis 연결 시도, 실패 시 폴백."""
    global _redis
    if not settings.REDIS_URL:
        logger.info("REDIS_URL 미설정 — 인메모리 캐시 사용")
        return
    try:
        import redis.asyncio as aioredis  # type: ignore
        client = aioredis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            socket_connect_timeout=3,
            socket_timeout=3,
        )
        await client.ping()
        _redis = client
        logger.info("✅ Redis 연결 성공: %s", settings.REDIS_URL.split("@")[-1])
    except Exception as exc:
        logger.warning("⚠️  Redis 연결 실패 (%s) — 인메모리 캐시로 동작", exc)
        _redis = None


async def close_redis() -> None:
    """앱 shutdown 시 호출."""
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None
        logger.info("Redis 연결 종료")


# ══════════════════════════════════════════════════════════
# 캐시 조작 API
# ══════════════════════════════════════════════════════════

async def cache_get(key: str) -> Optional[Any]:
    """캐시에서 값 조회. 없으면 None."""
    if _redis is not None:
        try:
            raw = await _redis.get(key)
            return json.loads(raw) if raw is not None else None
        except Exception as exc:
            logger.debug("Redis GET 오류 (폴백): %s", exc)

    # 인메모리 폴백
    import time
    if key in _mem:
        if _MEM_TTL.get(key, float("inf")) > time.time():
            _mem.move_to_end(key)
            return _mem[key]
        # 만료
        _mem.pop(key, None)
        _MEM_TTL.pop(key, None)
    return None


async def cache_set(key: str, value: Any, ttl: int = 3600) -> None:
    """캐시에 값 저장. ttl 초 후 만료."""
    if _redis is not None:
        try:
            await _redis.setex(key, ttl, json.dumps(value, ensure_ascii=False))
            return
        except Exception as exc:
            logger.debug("Redis SET 오류 (폴백): %s", exc)

    # 인메모리 LRU 폴백
    import time
    if key in _mem:
        _mem.move_to_end(key)
    _mem[key] = value
    _MEM_TTL[key] = time.time() + ttl
    if len(_mem) > _MEM_MAX:
        oldest = next(iter(_mem))
        _mem.pop(oldest)
        _MEM_TTL.pop(oldest, None)


async def cache_delete(key: str) -> None:
    """캐시 키 삭제."""
    if _redis is not None:
        try:
            await _redis.delete(key)
        except Exception:
            pass
    _mem.pop(key, None)
    _MEM_TTL.pop(key, None)


async def cache_flush_prefix(prefix: str) -> int:
    """특정 prefix 로 시작하는 모든 키 삭제. 삭제된 키 수 반환."""
    count = 0
    if _redis is not None:
        try:
            keys = await _redis.keys(f"{prefix}*")
            if keys:
                count = await _redis.delete(*keys)
            return count
        except Exception:
            pass
    # 메모리 폴백
    for k in list(_mem.keys()):
        if k.startswith(prefix):
            _mem.pop(k)
            _MEM_TTL.pop(k, None)
            count += 1
    return count


# ══════════════════════════════════════════════════════════
# 유틸
# ══════════════════════════════════════════════════════════

def make_key(*parts: Any, prefix: str = "sf") -> str:
    """여러 인수를 MD5 해시로 결합한 캐시 키 생성."""
    raw = "|".join(str(p) for p in parts)
    digest = hashlib.md5(raw.encode()).hexdigest()
    return f"{prefix}:{digest}"

"""
학습 흐름 추적 API
- POST /quiz-attempt   : 퀴즈 결과 저장 + 복습 스케줄 자동 계산
- GET  /summary/{uid}  : 흐름 대시보드 (최근 파일, 미완 퀴즈, 복습 필요, AI 추천)
- POST /review-done    : 복습 완료 → 다음 스케줄 업데이트
"""
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select

from app.core.database import get_session
from app.models.flow import QuizAttempt, QuizAttemptCreate, QuizAttemptRead, ReviewSchedule
from app.models.files import Files
from app.models.projects import Projects

router = APIRouter()


# ══════════════════════════════════════════════════════════
# SM-2 간격 반복 알고리즘
# ══════════════════════════════════════════════════════════
def _sm2_next(
    review_count: int,
    ease_factor: float,
    interval_days: int,
    quality: int,      # 0~5 (5=완벽, 0=완전히 잊음) — 점수 기반 자동 계산
) -> tuple[int, float, int]:
    """SM-2 알고리즘으로 다음 복습 일수 계산. (review_count, ease_factor, interval_days) 반환"""
    if quality < 3:
        # 틀렸으면 처음부터 재시작
        return 0, max(1.3, ease_factor - 0.2), 1

    if review_count == 0:
        new_interval = 1
    elif review_count == 1:
        new_interval = 3
    else:
        new_interval = round(interval_days * ease_factor)

    new_ef = ease_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    new_ef = max(1.3, new_ef)

    return review_count + 1, new_ef, max(1, new_interval)


def _score_to_quality(score: int, total: int) -> int:
    """점수 → SM-2 quality(0~5) 변환"""
    if total == 0:
        return 0
    pct = score / total
    if pct >= 0.9:
        return 5
    elif pct >= 0.8:
        return 4
    elif pct >= 0.6:
        return 3
    elif pct >= 0.4:
        return 2
    elif pct >= 0.2:
        return 1
    return 0


# ══════════════════════════════════════════════════════════
# POST /quiz-attempt  — 퀴즈 결과 저장
# ══════════════════════════════════════════════════════════
@router.post("/quiz-attempt", response_model=QuizAttemptRead)
def save_quiz_attempt(
    body: QuizAttemptCreate,
    session: Session = Depends(get_session),
):
    # 1) 퀴즈 기록 저장
    attempt = QuizAttempt(**body.model_dump())
    session.add(attempt)

    # 2) 복습 스케줄 업데이트 (파일별 SM-2)
    schedule = session.exec(
        select(ReviewSchedule)
        .where(ReviewSchedule.user_id == body.user_id)
        .where(ReviewSchedule.file_id == body.file_id)
    ).first()

    quality = _score_to_quality(body.score, body.total)
    now = datetime.utcnow()

    if schedule is None:
        r_count, ef, interval = _sm2_next(0, 2.5, 1, quality)
        # 파일 제목 조회
        f = session.get(Files, body.file_id)
        schedule = ReviewSchedule(
            user_id=body.user_id,
            file_id=body.file_id,
            file_title=f.title if f else None,
            review_count=r_count,
            ease_factor=ef,
            interval_days=interval,
            last_reviewed_at=now,
            next_review_at=now + timedelta(days=interval),
        )
    else:
        r_count, ef, interval = _sm2_next(
            schedule.review_count, schedule.ease_factor, schedule.interval_days, quality
        )
        schedule.review_count = r_count
        schedule.ease_factor = ef
        schedule.interval_days = interval
        schedule.last_reviewed_at = now
        schedule.next_review_at = now + timedelta(days=interval)

    session.add(schedule)
    session.commit()
    session.refresh(attempt)
    return attempt


# ══════════════════════════════════════════════════════════
# POST /review-done  — 복습 완료 → 스케줄 갱신
# ══════════════════════════════════════════════════════════
class ReviewDoneBody(BaseModel):
    user_id: str
    file_id: str
    quality: int = 4   # 0~5 (직접 평가하거나 기본값 4)


@router.post("/review-done")
def mark_review_done(
    body: ReviewDoneBody,
    session: Session = Depends(get_session),
):
    schedule = session.exec(
        select(ReviewSchedule)
        .where(ReviewSchedule.user_id == body.user_id)
        .where(ReviewSchedule.file_id == body.file_id)
    ).first()

    now = datetime.utcnow()
    if schedule is None:
        r_count, ef, interval = _sm2_next(0, 2.5, 1, body.quality)
        f = session.exec(select(Files).where(Files.id == body.file_id)).first()
        schedule = ReviewSchedule(
            user_id=body.user_id,
            file_id=body.file_id,
            file_title=f.title if f else None,
            review_count=r_count,
            ease_factor=ef,
            interval_days=interval,
            last_reviewed_at=now,
            next_review_at=now + timedelta(days=interval),
        )
    else:
        r_count, ef, interval = _sm2_next(
            schedule.review_count, schedule.ease_factor, schedule.interval_days, body.quality
        )
        schedule.review_count = r_count
        schedule.ease_factor = ef
        schedule.interval_days = interval
        schedule.last_reviewed_at = now
        schedule.next_review_at = now + timedelta(days=interval)

    session.add(schedule)
    session.commit()
    return {
        "next_review_at": schedule.next_review_at.isoformat(),
        "interval_days": interval,
        "review_count": r_count,
    }


# ══════════════════════════════════════════════════════════
# GET /summary/{user_id}  — 흐름 대시보드
# ══════════════════════════════════════════════════════════
@router.get("/summary/{user_id}")
def get_flow_summary(
    user_id: str,
    session: Session = Depends(get_session),
):
    now = datetime.utcnow()

    # 유저 프로젝트 + 파일 목록
    projects = session.exec(
        select(Projects).where(Projects.user_id == user_id)
    ).all()
    project_ids = [p.id for p in projects]
    if not project_ids:
        return _empty_summary()

    # ── 최근 작업 파일 (최대 4개) ──────────────────────────
    recent_files = session.exec(
        select(Files)
        .where(Files.project_id.in_(project_ids))
        .where(Files.content != None)
        .where(Files.content != "")
        .order_by(Files.update_at.desc())
        .limit(4)
    ).all()

    # ── 퀴즈 한 번도 안 본 파일 (미완 퀴즈 대상, 내용 있는 파일) ──
    attempted_file_ids = set(
        row.file_id for row in session.exec(
            select(QuizAttempt.file_id)
            .where(QuizAttempt.user_id == user_id)
        ).all()
    )
    all_content_files = session.exec(
        select(Files)
        .where(Files.project_id.in_(project_ids))
        .where(Files.content != None)
        .where(Files.content != "")
    ).all()

    no_quiz_files = [f for f in all_content_files if f.id not in attempted_file_ids][:4]

    # 퀴즈 봤지만 점수 낮은 파일 (score/total < 0.6)
    low_score_attempts = session.exec(
        select(QuizAttempt)
        .where(QuizAttempt.user_id == user_id)
        .order_by(QuizAttempt.created_at.desc())
    ).all()
    seen_low: set[str] = set()
    weak_files = []
    for a in low_score_attempts:
        if a.file_id in seen_low:
            continue
        if a.total > 0 and a.score / a.total < 0.6:
            seen_low.add(a.file_id)
            f = session.get(Files, a.file_id)
            if f:
                weak_files.append({
                    "file_id": f.id,
                    "title": f.title or "제목 없음",
                    "score": a.score,
                    "total": a.total,
                    "pct": round(a.score / a.total * 100),
                })
        if len(weak_files) >= 3:
            break

    # ── 복습 필요 파일 (next_review_at <= now) ──────────────
    due_schedules = session.exec(
        select(ReviewSchedule)
        .where(ReviewSchedule.user_id == user_id)
        .where(ReviewSchedule.next_review_at <= now)
        .order_by(ReviewSchedule.next_review_at.asc())
        .limit(4)
    ).all()
    due_reviews = []
    for s in due_schedules:
        f = session.get(Files, s.file_id)
        if f:
            overdue_days = (now - s.next_review_at).days if s.next_review_at else 0
            due_reviews.append({
                "file_id": s.file_id,
                "title": f.title or "제목 없음",
                "overdue_days": overdue_days,
                "review_count": s.review_count,
                "interval_days": s.interval_days,
            })

    # ── 다가오는 복습 예정 (next 7일) ──────────────────────
    upcoming = session.exec(
        select(ReviewSchedule)
        .where(ReviewSchedule.user_id == user_id)
        .where(ReviewSchedule.next_review_at > now)
        .where(ReviewSchedule.next_review_at <= now + timedelta(days=7))
        .order_by(ReviewSchedule.next_review_at.asc())
        .limit(3)
    ).all()
    upcoming_reviews = []
    for s in upcoming:
        f = session.get(Files, s.file_id)
        if f:
            days_left = max(0, (s.next_review_at - now).days)
            upcoming_reviews.append({
                "file_id": s.file_id,
                "title": f.title or "제목 없음",
                "days_left": days_left,
                "next_review_at": s.next_review_at.isoformat(),
            })

    # ── 통계 ──────────────────────────────────────────────
    total_attempts = session.exec(
        select(QuizAttempt).where(QuizAttempt.user_id == user_id)
    ).all()
    total_quizzes = len(total_attempts)
    avg_score = 0
    if total_attempts:
        valid = [(a.score, a.total) for a in total_attempts if a.total > 0]
        avg_score = round(sum(s / t * 100 for s, t in valid) / len(valid)) if valid else 0

    total_schedules = session.exec(
        select(ReviewSchedule).where(ReviewSchedule.user_id == user_id)
    ).all()
    completed_reviews = sum(1 for s in total_schedules if s.review_count > 0)

    return {
        "recent_files": [
            {
                "file_id": f.id,
                "title": f.title or "제목 없음",
                "tags": f.tags or "",
                "icon": f.icon or "",
                "update_at": f.update_at.isoformat() if f.update_at else None,
                "char_count": len(f.content or ""),
            }
            for f in recent_files
        ],
        "no_quiz_files": [
            {
                "file_id": f.id,
                "title": f.title or "제목 없음",
                "tags": f.tags or "",
                "icon": f.icon or "",
                "char_count": len(f.content or ""),
            }
            for f in no_quiz_files
        ],
        "weak_files": weak_files,
        "due_reviews": due_reviews,
        "upcoming_reviews": upcoming_reviews,
        "stats": {
            "total_quizzes": total_quizzes,
            "avg_score": avg_score,
            "completed_reviews": completed_reviews,
            "due_count": len(due_reviews),
            "no_quiz_count": len(no_quiz_files),
        },
    }


def _empty_summary():
    return {
        "recent_files": [],
        "no_quiz_files": [],
        "weak_files": [],
        "due_reviews": [],
        "upcoming_reviews": [],
        "stats": {
            "total_quizzes": 0,
            "avg_score": 0,
            "completed_reviews": 0,
            "due_count": 0,
            "no_quiz_count": 0,
        },
    }


# ══════════════════════════════════════════════════════════
# POST /next-actions  — AI 다음 행동 추천
# ══════════════════════════════════════════════════════════
class NextActionsReq(BaseModel):
    user_id: str
    recent_titles: List[str] = []
    due_review_titles: List[str] = []
    weak_titles: List[str] = []
    no_quiz_titles: List[str] = []


@router.post("/next-actions")
async def get_next_actions(req: NextActionsReq):
    """학습 현황을 분석해 오늘 할 행동 3가지를 추천한다."""
    parts = []
    if req.recent_titles:
        parts.append(f"최근 작업 파일: {', '.join(req.recent_titles[:3])}")
    if req.due_review_titles:
        parts.append(f"복습 기한 초과: {', '.join(req.due_review_titles[:3])}")
    if req.weak_titles:
        parts.append(f"퀴즈 점수 낮음 (<60%): {', '.join(req.weak_titles[:3])}")
    if req.no_quiz_titles:
        parts.append(f"아직 퀴즈 안 본 파일: {', '.join(req.no_quiz_titles[:3])}")

    if not parts:
        return {"actions": [
            {"icon": "📝", "title": "새 노트 작성", "description": "학습 흐름을 시작해보세요.", "type": "create"},
        ]}

    context = "\n".join(parts)

    try:
        import google.generativeai as genai
        from app.core.config import settings
        if not settings.GEMINI_API_KEY:
            raise RuntimeError("no key")
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel(settings.GEMINI_MODEL)
        prompt = (
            f"학습자의 현재 상태:\n{context}\n\n"
            "위 상태를 바탕으로 오늘 학습자가 해야 할 행동 3가지를 추천하세요.\n"
            "각 행동은 구체적이고 실행 가능해야 합니다.\n\n"
            "반드시 아래 JSON 배열만 출력하세요 (설명 없이):\n"
            '[{"icon":"이모지","title":"짧은 행동명(10자 이내)","description":"구체적인 설명(30자 이내)","type":"review|quiz|read|create 중 하나"}]\n'
            "규칙: 정확히 3개, 이모지 1개, title 10자 이내, description 30자 이내, JSON만 출력"
        )
        cfg = genai.types.GenerationConfig(temperature=0.3, max_output_tokens=300)
        response = model.generate_content(prompt, generation_config=cfg)
        raw = (response.text or "").strip()
        raw = raw.replace("```json", "").replace("```", "").strip()
        import json, re
        s, e = raw.find("["), raw.rfind("]")
        if s != -1 and e != -1:
            actions = json.loads(raw[s:e+1])
            return {"actions": actions[:3]}
    except Exception:
        pass

    # 폴백: 규칙 기반 추천
    actions = []
    if req.due_review_titles:
        actions.append({
            "icon": "🔄",
            "title": "복습하기",
            "description": f"'{req.due_review_titles[0]}' 복습 기한이 지났어요",
            "type": "review",
        })
    if req.weak_titles:
        actions.append({
            "icon": "💪",
            "title": "취약점 보강",
            "description": f"'{req.weak_titles[0]}' 퀴즈를 다시 풀어보세요",
            "type": "quiz",
        })
    if req.no_quiz_titles:
        actions.append({
            "icon": "❓",
            "title": "퀴즈 시작",
            "description": f"'{req.no_quiz_titles[0]}' 퀴즈를 아직 안 풀었어요",
            "type": "quiz",
        })
    if not actions:
        actions.append({
            "icon": "📖",
            "title": "노트 복습",
            "description": f"'{req.recent_titles[0]}' 내용을 다시 읽어보세요",
            "type": "read",
        })

    return {"actions": actions[:3]}

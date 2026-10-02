from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, get_current_user
from ..models import Notification, utcnow
from ..schemas import PreferencesIn, notification_out
from ..services.records import preferences_for

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
def list_notifications(
    status: str = Query("all", pattern="^(all|unread|read)$"),
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = select(Notification).where(Notification.user_id == current.id)
    if status == "unread":
        query = query.where(Notification.is_read.is_(False))
    elif status == "read":
        query = query.where(Notification.is_read.is_(True))
    rows = db.scalars(query.order_by(Notification.created_at.desc()).limit(limit).offset(offset))
    unread = db.scalar(select(func.count(Notification.id)).where(Notification.user_id == current.id, Notification.is_read.is_(False)))
    return {"items": [notification_out(n) for n in rows], "unread_count": unread}


@router.get("/unread-count")
def unread_count(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    return {"unread_count": db.scalar(select(func.count(Notification.id)).where(Notification.user_id == current.id, Notification.is_read.is_(False)))}


@router.post("/{notification_id}/read")
def mark_read(notification_id: str, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    n = db.get(Notification, notification_id)
    if n is None or n.user_id != current.id:
        raise errors.not_found("Notification")
    if not n.is_read:
        n.is_read, n.read_at = True, utcnow()
        db.commit()
    return notification_out(n)


@router.post("/read-all")
def mark_all_read(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    db.execute(update(Notification).where(Notification.user_id == current.id, Notification.is_read.is_(False)).values(is_read=True, read_at=utcnow()))
    db.commit()
    return {"unread_count": 0}


def _prefs_out(p) -> dict:
    return {k: getattr(p, k) for k in ("food_reminders", "lifestyle_reminders", "follow_up_reminders", "doctor_notifications")}


@router.get("/preferences")
def get_preferences(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    prefs = preferences_for(db, current.id)
    db.commit()
    return _prefs_out(prefs)


@router.put("/preferences")
def set_preferences(body: PreferencesIn, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    prefs = preferences_for(db, current.id)
    for key, value in body.model_dump(exclude_none=True).items():
        setattr(prefs, key, value)
    db.commit()
    return _prefs_out(prefs)

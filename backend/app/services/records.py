"""Shared helpers for record codes, audit logging and notifications."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..deps import CurrentUser
from ..models import AuditLog, Counter, Notification, NotificationPreference, User


def next_code(db: Session, name: str, prefix: str, width: int = 6) -> str:
    counter = db.get(Counter, name)
    if counter is None:
        counter = Counter(name=name, value=0)
        db.add(counter)
        db.flush()
    counter.value += 1
    db.flush()
    return f"{prefix}-{counter.value:0{width}d}"


def audit(
    db: Session,
    actor: CurrentUser | None,
    action: str,
    entity_type: str | None = None,
    entity_id: str | None = None,
    entity_label: str | None = None,
    details: dict | None = None,
) -> None:
    """Records who did what, when, to which entity. Never pass medical content in details."""
    db.add(
        AuditLog(
            actor_user_id=actor.id if actor else None,
            actor_role=actor.role if actor else "system",
            actor_name=actor.name if actor else "System",
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            entity_label=entity_label,
            details=details or {},
        )
    )


# Maps notification types to the preference that can silence them.
_PREFERENCE_FOR_TYPE = {
    "food_reminder": "food_reminders",
    "lifestyle_reminder": "lifestyle_reminders",
    "follow_up_reminder": "follow_up_reminders",
    "patient_update": "doctor_notifications",
    "new_report": "doctor_notifications",
}


def preferences_for(db: Session, user_id: str) -> NotificationPreference:
    prefs = db.get(NotificationPreference, user_id)
    if prefs is None:
        prefs = NotificationPreference(user_id=user_id)
        db.add(prefs)
        db.flush()
    return prefs


def notify(
    db: Session,
    user_id: str,
    type: str,
    title: str,
    body: str,
    entity_type: str | None = None,
    entity_id: str | None = None,
    patient_id: str | None = None,
    dedupe_key: str | None = None,
) -> Notification | None:
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        return None
    pref_name = _PREFERENCE_FOR_TYPE.get(type)
    if pref_name and not getattr(preferences_for(db, user_id), pref_name):
        return None
    if dedupe_key and db.scalar(select(Notification.id).where(Notification.dedupe_key == dedupe_key)):
        return None
    notification = Notification(
        user_id=user_id,
        type=type,
        title=title,
        body=body,
        entity_type=entity_type,
        entity_id=entity_id,
        patient_id=patient_id,
        dedupe_key=dedupe_key,
    )
    db.add(notification)
    return notification

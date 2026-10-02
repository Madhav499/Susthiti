"""Periodic reminders (follow-up, food logging, lifestyle). Respects notification preferences
and deduplicates so the same reminder is never sent twice."""

import asyncio
import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import (
    AccessRequest,
    Doctor,
    FoodEntry,
    LifestyleMetric,
    Patient,
    Prescription,
    User,
    Visit,
)
from .records import notify

log = logging.getLogger("susthiti.reminders")


def run_reminders(db: Session, now: datetime | None = None) -> int:
    now = now or datetime.now(timezone.utc)
    today = now.date()
    sent = 0
    sent += _follow_ups(db, today)
    sent += _birthdays(db)
    if now.hour >= 19:
        sent += _food_reminders(db, today)
    if now.hour >= 18 and today.weekday() == 6:
        sent += _lifestyle_reminders(db, today)
    db.commit()
    return sent


def _follow_ups(db: Session, today: date) -> int:
    sent = 0
    tomorrow = today + timedelta(days=1)
    rows = [
        *[("visit", v.id, v.patient_id, v.doctor_id, v.follow_up_date) for v in db.scalars(select(Visit).where(Visit.follow_up_date.in_([today, tomorrow])))],
        *[("prescription", p.id, p.patient_id, p.doctor_id, p.follow_up_date) for p in db.scalars(select(Prescription).where(Prescription.follow_up_date.in_([today, tomorrow])))],
    ]
    for entity, entity_id, patient_id, doctor_id, due in rows:
        when = "today" if due == today else "tomorrow"
        patient = db.get(Patient, patient_id)
        if notify(db, patient.user_id, "follow_up_reminder", "Follow-up reminder", f"You have a follow-up due {when}.",
                  entity, entity_id, patient_id, dedupe_key=f"fu:{entity_id}:{due}:p"):
            sent += 1
        doctor = db.get(Doctor, doctor_id)
        still_authorized = db.scalar(select(AccessRequest.id).where(AccessRequest.doctor_id == doctor_id, AccessRequest.patient_id == patient_id, AccessRequest.status == "approved"))
        if doctor and still_authorized and notify(
            db, doctor.user_id, "follow_up_reminder", "Follow-up due",
            f"{patient.user.full_name} ({patient.patient_code}) has a follow-up due {when}.",
            entity, entity_id, patient_id, dedupe_key=f"fu:{entity_id}:{due}:d",
        ):
            sent += 1
    return sent


def _birthdays(db: Session) -> int:
    from .health_data.body import is_birthday, local_today

    today = local_today()
    sent = 0
    for patient in _active_patients(db):
        if is_birthday(patient.date_of_birth, today) and notify(
            db, patient.user_id, "birthday", f"Happy birthday, {patient.user.full_name.split()[0]}!",
            "Wishing you a happy and healthy year ahead, from all of us at SUSTHITI.", "patient", patient.id, patient.id,
            dedupe_key=f"birthday:{patient.id}:{today.year}",
        ):
            sent += 1
    return sent


def _active_patients(db: Session):
    return db.scalars(select(Patient).join(User).where(User.is_active.is_(True)))


def _food_reminders(db: Session, today: date) -> int:
    sent = 0
    start = datetime(today.year, today.month, today.day, tzinfo=timezone.utc)
    for patient in _active_patients(db):
        logged = db.scalar(select(func.count(FoodEntry.id)).where(FoodEntry.patient_id == patient.id, FoodEntry.eaten_at >= start))
        if not logged and notify(db, patient.user_id, "food_reminder", "Log today's meals",
                                 "No meals recorded today. A quick log helps you and your doctor see patterns.",
                                 dedupe_key=f"food:{patient.id}:{today}"):
            sent += 1
    return sent


def _lifestyle_reminders(db: Session, today: date) -> int:
    sent = 0
    since = datetime(today.year, today.month, today.day, tzinfo=timezone.utc) - timedelta(days=7)
    for patient in _active_patients(db):
        recent = db.scalar(select(func.count(LifestyleMetric.id)).where(LifestyleMetric.patient_id == patient.id, LifestyleMetric.recorded_at >= since))
        if not recent and notify(db, patient.user_id, "lifestyle_reminder", "Keep your lifestyle data current",
                                 "No activity or sleep data this week. Sync your device or add a reading.",
                                 dedupe_key=f"life:{patient.id}:{today}"):
            sent += 1
    return sent


async def reminder_loop(session_factory, interval_minutes: int) -> None:
    while True:
        try:
            with session_factory() as db:
                count = run_reminders(db)
                if count:
                    log.info("reminders sent count=%s", count)
        except Exception as exc:  # keep the loop alive, but never silently
            log.exception("reminder run failed type=%s", type(exc).__name__)
        await asyncio.sleep(interval_minutes * 60)

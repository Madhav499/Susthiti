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
    FollowUp,
    FoodEntry,
    GlucoseReading,
    Patient,
    Prescription,
    Surgery,
    User,
    Visit,
)
from .records import notify

log = logging.getLogger("susthiti.reminders")


def run_reminders(db: Session, now: datetime | None = None) -> int:
    from .health_data.body import to_local_datetime

    now = now or datetime.now(timezone.utc)
    today = now.date()
    sent = 0
    sent += _follow_ups(db, today)
    sent += _surgeries(db, today)
    sent += _birthdays(db)
    if now.hour >= 19:
        sent += _food_reminders(db, today)
    local_now = to_local_datetime(now)
    if local_now.hour >= 20:  # 8pm local time -- a plausible point by which a day's entries are done
        local_today = local_now.date()
        sent += _metric_reminders(db, local_today)
        sent += _glucose_reminders(db, local_today)
    db.commit()
    return sent


def _follow_ups(db: Session, today: date) -> int:
    sent = 0
    tomorrow = today + timedelta(days=1)
    rows = [
        *[("visit", v.id, v.patient_id, v.doctor_id, v.follow_up_date) for v in db.scalars(select(Visit).where(Visit.follow_up_date.in_([today, tomorrow])))],
        *[("prescription", p.id, p.patient_id, p.doctor_id, p.follow_up_date) for p in db.scalars(select(Prescription).where(Prescription.follow_up_date.in_([today, tomorrow])))],
        *[("follow_up", f.id, f.patient_id, f.doctor_id, f.due_date)
          for f in db.scalars(select(FollowUp).where(FollowUp.status == "scheduled", FollowUp.due_date.in_([today, tomorrow])))],
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


def _surgeries(db: Session, today: date) -> int:
    sent = 0
    tomorrow = today + timedelta(days=1)

    def _local_date(dt: datetime) -> date:
        return (dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)).date()

    rows = [s for s in db.scalars(select(Surgery).where(Surgery.status == "scheduled", Surgery.scheduled_at.is_not(None)))
            if _local_date(s.scheduled_at) in (today, tomorrow)]
    for s in rows:
        when = "today" if _local_date(s.scheduled_at) == today else "tomorrow"
        patient = db.get(Patient, s.patient_id)
        if notify(db, patient.user_id, "surgery_reminder", f"Surgery {when}", f"Your surgery ({s.name}) is {when}.",
                  "surgery", s.id, s.patient_id, dedupe_key=f"surg:{s.id}:{when}:p"):
            sent += 1
        doctor = db.get(Doctor, s.doctor_id)
        still_authorized = db.scalar(select(AccessRequest.id).where(AccessRequest.doctor_id == s.doctor_id, AccessRequest.patient_id == s.patient_id, AccessRequest.status == "approved"))
        if doctor and still_authorized and notify(
            db, doctor.user_id, "surgery_reminder", f"Surgery {when}",
            f"{patient.user.full_name} ({patient.patient_code})'s surgery ({s.name}) is {when}.",
            "surgery", s.id, s.patient_id, dedupe_key=f"surg:{s.id}:{when}:d",
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
                                 "lifestyle_metric", "food", patient.id, dedupe_key=f"food:{patient.id}:{today}"):
            sent += 1
    return sent


_LIFESTYLE_METRIC_LABELS = {
    "steps": "step count", "sleep": "sleep", "heart_rate": "heart rate",
    "activity": "activity minutes", "blood_pressure": "blood pressure", "spo2": "SpO2 reading",
}


def _metric_reminders(db: Session, today: date) -> int:
    """One evening nudge per lifestyle metric per patient per local day, for any of the six
    wearable/manual metrics with nothing recorded yet today. Reuses daily_series()'s own
    local_date-aware bucketing instead of re-deriving it."""
    from .lifestyle_data import daily_series

    sent = 0
    for patient in _active_patients(db):
        for metric, label in _LIFESTYLE_METRIC_LABELS.items():
            if daily_series(db, patient.id, metric, today, today):
                continue  # already has a recorded value today
            if notify(db, patient.user_id, "lifestyle_reminder", f"Log today's {label}",
                      f"No {label} recorded today. A quick log helps you and your doctor see patterns.",
                      "lifestyle_metric", metric, patient.id, dedupe_key=f"life:{metric}:{patient.id}:{today}"):
                sent += 1
    return sent


def _glucose_reminders(db: Session, today: date) -> int:
    from .health_data.body import to_local_date

    window_start = datetime(today.year, today.month, today.day, tzinfo=timezone.utc) - timedelta(days=1)
    window_end = datetime(today.year, today.month, today.day, tzinfo=timezone.utc) + timedelta(days=2)
    sent = 0
    for patient in _active_patients(db):
        measured = db.scalars(select(GlucoseReading.measured_at).where(
            GlucoseReading.patient_id == patient.id, GlucoseReading.measured_at >= window_start, GlucoseReading.measured_at < window_end,
        ))
        if any(to_local_date(m) == today for m in measured):
            continue
        if notify(db, patient.user_id, "lifestyle_reminder", "Log today's glucose",
                  "No glucose reading recorded today. A quick log helps you and your doctor see patterns.",
                  "lifestyle_metric", "glucose", patient.id, dedupe_key=f"life:glucose:{patient.id}:{today}"):
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

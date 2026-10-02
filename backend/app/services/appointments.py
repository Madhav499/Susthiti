"""Appointments agreed between a patient and a doctor.

Either side starts one: a doctor suggests a date and time, or a patient asks for one (with a
preferred time or not). The other side then accepts, proposes another time, or declines; a
proposal hands the decision back. An appointment is final only when both have agreed on the
time (status "confirmed"). Either side can cancel. Every step is kept (AppointmentEvent) and the
other side is notified; confirmed appointments get reminders the day before and on the day.
"""

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..config import get_settings
from ..deps import CurrentUser, doctor_has_access
from ..models import AppointmentEvent, AppointmentRecommendation, Doctor, Patient
from ..schemas import iso
from .records import notify

AWAITING_PATIENT = "awaiting_patient"
AWAITING_DOCTOR = "awaiting_doctor"
CONFIRMED = "confirmed"
DECLINED = "declined"
CANCELLED = "cancelled"
OPEN = (AWAITING_PATIENT, AWAITING_DOCTOR, CONFIRMED)

MAX_AHEAD = timedelta(days=366)


def _tz() -> ZoneInfo:
    return ZoneInfo(get_settings().local_timezone)


def when_label(at: datetime | None) -> str:
    if at is None:
        return "a time to be agreed"
    local = _aware(at).astimezone(_tz())
    return local.strftime("%a %d %b %Y, %I:%M %p").replace(" 0", " ")


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def status_of(a: AppointmentRecommendation) -> str:
    return a.status or AWAITING_PATIENT  # recommendations made before this workflow


def _check_time(at: datetime | None, required: bool) -> datetime | None:
    if at is None:
        if required:
            raise errors.unprocessable("Choose the date and time of the appointment.", {"field": "scheduled_for"})
        return None
    at = _aware(at).astimezone(timezone.utc)
    now = datetime.now(timezone.utc)
    if at <= now:
        raise errors.unprocessable("Choose a date and time in the future.", {"field": "scheduled_for"})
    if at > now + MAX_AHEAD:
        raise errors.unprocessable("Choose a date within the next year.", {"field": "scheduled_for"})
    return at


def _event(db: Session, a: AppointmentRecommendation, current: CurrentUser, action: str, note: str | None = None) -> None:
    db.add(AppointmentEvent(appointment_id=a.id, actor_user_id=current.id, actor_role=current.role, actor_name=current.name,
                            action=action, scheduled_for=a.recommended_for, note=note))


def _patient_and_doctor(db: Session, a: AppointmentRecommendation) -> tuple[Patient, Doctor]:
    return db.get(Patient, a.patient_id), db.get(Doctor, a.doctor_id)


def create(db: Session, current: CurrentUser, patient: Patient, doctor: Doctor, reason: str, scheduled_for: datetime | None,
           side_effect_id: str | None = None, time_required: bool = True) -> AppointmentRecommendation:
    by_doctor = current.role == "doctor"
    at = _check_time(scheduled_for, required=by_doctor and time_required)
    now = datetime.now(timezone.utc)
    a = AppointmentRecommendation(
        patient_id=patient.id, doctor_id=doctor.id, doctor_name=doctor.user.full_name, side_effect_id=side_effect_id, reason=reason.strip(),
        recommended_for=at, status=AWAITING_PATIENT if by_doctor else AWAITING_DOCTOR, requested_by_role=current.role,
        proposed_by_role=current.role if at else None, updated_at=now,
    )
    db.add(a)
    db.flush()
    _event(db, a, current, "requested")
    if by_doctor:
        notify(db, patient.user_id, "appointment_recommendation", "Appointment suggested",
               f"Dr. {doctor.user.full_name} suggests an appointment on {when_label(at)}. Accept it or suggest another time.",
               "appointment", a.id, patient.id)
    else:
        notify(db, doctor.user_id, "appointment_request", "Appointment requested",
               f"{patient.user.full_name} ({patient.patient_code}) asks for an appointment"
               + (f", preferably {when_label(at)}." if at else ". Please choose a time."), "appointment", a.id, patient.id)
    return a


def respond(db: Session, current: CurrentUser, a: AppointmentRecommendation, action: str, scheduled_for: datetime | None, note: str | None) -> AppointmentRecommendation:
    """action: accept | propose | decline | cancel, by the patient or the appointment's doctor."""
    patient, doctor = _patient_and_doctor(db, a)
    is_doctor = current.role == "doctor"
    if is_doctor:
        if doctor is None or doctor.user_id != current.id:
            raise errors.forbidden()
        if not doctor_has_access(db, doctor.id, patient.id):
            raise errors.forbidden("Your access to this patient has ended.")
    elif current.role != "patient" or patient.user_id != current.id:
        raise errors.forbidden()

    status = status_of(a)
    my_turn = AWAITING_DOCTOR if is_doctor else AWAITING_PATIENT
    now = datetime.now(timezone.utc)
    if action == "cancel":
        if status not in OPEN:
            raise errors.conflict("This appointment is already closed.")
        a.status = CANCELLED
    elif action == "decline":
        if status != my_turn:
            raise errors.conflict("There is nothing to decline right now.")
        a.status = DECLINED
    elif action == "accept":
        if status != my_turn:
            raise errors.conflict("This appointment isn't waiting for your answer.")
        if a.recommended_for is None:
            if not is_doctor:
                raise errors.unprocessable("No time has been proposed yet. Suggest a time instead.")
            # A patient asked without a time: the doctor approves by assigning one.
            a.recommended_for = _check_time(scheduled_for, required=True)
            a.proposed_by_role = "doctor"
        elif _aware(a.recommended_for) <= now:
            raise errors.conflict("That time has passed. Suggest a new time instead.")
        a.status = CONFIRMED
        a.confirmed_at = now
    elif action == "propose":
        if status not in OPEN:
            raise errors.conflict("This appointment is already closed.")
        a.recommended_for = _check_time(scheduled_for, required=True)
        a.proposed_by_role = current.role
        a.status = AWAITING_PATIENT if is_doctor else AWAITING_DOCTOR
        a.confirmed_at = None
    else:
        raise errors.unprocessable("Unknown action.")
    a.updated_at = now
    _event(db, a, current, {"accept": "accepted", "propose": "proposed", "decline": "declined", "cancel": "cancelled"}[action], note)

    # Tell the other side.
    who = f"Dr. {current.name}" if is_doctor else f"{patient.user.full_name} ({patient.patient_code})"
    text = {
        "accept": f"{who} confirmed the appointment on {when_label(a.recommended_for)}.",
        "propose": f"{who} suggests {when_label(a.recommended_for)} instead. Accept it or suggest another time.",
        "decline": f"{who} declined the appointment.",
        "cancel": f"{who} cancelled the appointment on {when_label(a.recommended_for)}.",
    }[action] + (f" Note: {note.strip()}" if note and note.strip() else "")
    title = {"accept": "Appointment confirmed", "propose": "New time suggested", "decline": "Appointment declined", "cancel": "Appointment cancelled"}[action]
    target = patient.user_id if is_doctor else doctor.user_id
    notify(db, target, "appointment_update", title, text, "appointment", a.id, patient.id)
    return a


def appointment_out(db: Session, a: AppointmentRecommendation, with_events: bool = True) -> dict:
    patient = db.get(Patient, a.patient_id)
    out = {
        "id": a.id, "patient_id": a.patient_id, "patient_name": patient.user.full_name if patient else None,
        "patient_code": patient.patient_code if patient else None, "doctor_id": a.doctor_id, "doctor_name": a.doctor_name,
        "side_effect_id": a.side_effect_id, "reason": a.reason,
        "status": status_of(a), "scheduled_for": iso(a.recommended_for), "recommended_for": iso(a.recommended_for),
        "requested_by_role": a.requested_by_role or "doctor", "proposed_by_role": a.proposed_by_role or ("doctor" if a.recommended_for else None),
        "confirmed_at": iso(a.confirmed_at), "created_at": iso(a.created_at), "updated_at": iso(a.updated_at or a.created_at),
    }
    if with_events:
        rows = db.scalars(select(AppointmentEvent).where(AppointmentEvent.appointment_id == a.id).order_by(AppointmentEvent.created_at))
        out["events"] = [{"action": e.action, "by_role": e.actor_role, "by_name": e.actor_name, "scheduled_for": iso(e.scheduled_for),
                          "note": e.note, "at": iso(e.created_at)} for e in rows]
    return out


def local_day_bounds(days_from_today: int = 0) -> tuple[datetime, datetime]:
    today = datetime.now(timezone.utc).astimezone(_tz()).date() + timedelta(days=days_from_today)
    start = datetime(today.year, today.month, today.day, tzinfo=_tz()).astimezone(timezone.utc)
    return start, start + timedelta(days=1)


def reminders(db: Session, now: datetime | None = None) -> int:
    """Confirmed appointments: a reminder the day before and one on the day, to both sides."""
    now = now or datetime.now(timezone.utc)
    sent = 0
    rows = db.scalars(select(AppointmentRecommendation).where(
        AppointmentRecommendation.status == CONFIRMED,
        AppointmentRecommendation.recommended_for > now,
        AppointmentRecommendation.recommended_for <= now + timedelta(days=2),
    ))
    today_local = now.astimezone(_tz()).date()
    for a in rows:
        at_local = _aware(a.recommended_for).astimezone(_tz())
        days = (at_local.date() - today_local).days
        if days == 1:
            kind, word = "day_before", "tomorrow"
        elif days == 0:
            kind, word = "same_day", "today"
        else:
            continue
        patient, doctor = _patient_and_doctor(db, a)
        time = at_local.strftime("%I:%M %p").lstrip("0")
        if notify(db, patient.user_id, "appointment_reminder", f"Appointment {word}",
                  f"Your appointment with Dr. {a.doctor_name} is {word} at {time}.", "appointment", a.id, patient.id,
                  dedupe_key=f"appt:{a.id}:{kind}:{a.recommended_for:%Y%m%d%H%M}:p"):
            sent += 1
        if doctor and notify(db, doctor.user_id, "appointment_reminder", f"Appointment {word}",
                             f"Appointment with {patient.user.full_name} ({patient.patient_code}) {word} at {time}.", "appointment", a.id, patient.id,
                             dedupe_key=f"appt:{a.id}:{kind}:{a.recommended_for:%Y%m%d%H%M}:d"):
            sent += 1
    return sent

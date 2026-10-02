"""Appointments: suggested by a doctor or requested by a patient, confirmed by both."""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, current_doctor, doctor_has_access, require_doctor, require_patient, require_record_reader
from ..models import AppointmentRecommendation, Doctor
from ..services import appointments as svc
from ..services.records import audit

router = APIRouter(tags=["appointments"])


class AppointmentRequestIn(BaseModel):
    doctor_id: str
    reason: str = Field(min_length=3, max_length=1000)
    preferred_time: datetime | None = None


class AppointmentResponseIn(BaseModel):
    action: str = Field(pattern="^(accept|propose|decline|cancel)$")
    scheduled_for: datetime | None = None
    note: str | None = Field(default=None, max_length=500)


@router.post("/patients/{patient_id}/appointments", status_code=201)
def request_appointment(patient_id: str, body: AppointmentRequestIn, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    """A patient asks one of their doctors for an appointment."""
    patient = authorize_patient(db, current, patient_id)
    doctor = db.get(Doctor, body.doctor_id)
    if doctor is None or not doctor_has_access(db, doctor.id, patient.id):
        raise errors.unprocessable("Choose one of your doctors.", {"field": "doctor_id"})
    a = svc.create(db, current, patient, doctor, body.reason, body.preferred_time)
    audit(db, current, "appointment_requested", "appointment", a.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return svc.appointment_out(db, a)


@router.get("/patients/{patient_id}/appointments")
def list_patient_appointments(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    rows = db.scalars(select(AppointmentRecommendation).where(AppointmentRecommendation.patient_id == patient.id)
                      .order_by(AppointmentRecommendation.created_at.desc()))
    return {"items": [svc.appointment_out(db, a) for a in rows]}


@router.post("/appointments/{appointment_id}/respond")
def respond(appointment_id: str, body: AppointmentResponseIn, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    if current.role == "admin":
        raise errors.forbidden()
    a = db.get(AppointmentRecommendation, appointment_id)
    if a is None:
        raise errors.not_found("Appointment")
    svc.respond(db, current, a, body.action, body.scheduled_for, body.note)
    audit(db, current, f"appointment_{body.action}", "appointment", a.id, None, {"status": a.status})
    db.commit()
    return svc.appointment_out(db, a)


@router.get("/doctor/appointments")
def doctor_schedule(current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    """The doctor's day: confirmed appointments today and in the next 7 days, and requests or new
    times waiting for the doctor's answer."""
    doctor = current_doctor(db, current)
    today_start, today_end = svc.local_day_bounds(0)
    week_end = today_start + timedelta(days=8)
    now = datetime.now(timezone.utc)
    mine = select(AppointmentRecommendation).where(AppointmentRecommendation.doctor_id == doctor.id)
    confirmed = list(db.scalars(mine.where(AppointmentRecommendation.status == svc.CONFIRMED,
                                           AppointmentRecommendation.recommended_for >= today_start,
                                           AppointmentRecommendation.recommended_for < week_end)
                                .order_by(AppointmentRecommendation.recommended_for)))
    awaiting_you = list(db.scalars(mine.where(AppointmentRecommendation.status == svc.AWAITING_DOCTOR).order_by(AppointmentRecommendation.created_at)))
    awaiting_patient = list(db.scalars(mine.where(AppointmentRecommendation.status == svc.AWAITING_PATIENT,
                                                  AppointmentRecommendation.recommended_for > now)
                                       .order_by(AppointmentRecommendation.recommended_for)))

    def at(a):
        at_ = a.recommended_for
        return at_ if at_.tzinfo else at_.replace(tzinfo=timezone.utc)

    return {
        "today": [svc.appointment_out(db, a, False) for a in confirmed if today_start <= at(a) < today_end],
        "upcoming": [svc.appointment_out(db, a, False) for a in confirmed if at(a) >= today_end],
        "awaiting_you": [svc.appointment_out(db, a) for a in awaiting_you],
        "awaiting_patient": [svc.appointment_out(db, a, False) for a in awaiting_patient],
    }

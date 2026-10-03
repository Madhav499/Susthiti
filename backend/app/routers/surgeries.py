"""Surgery records. `internal_notes` is doctor/admin only -- `surgery_out(..., include_internal=)`
decides this per response, never the Flutter client, so a patient's own request simply never
receives the field. Scheduling state, like FollowUp: status and scheduled_at are updated in
place as the surgery is planned, rescheduled and carried out."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, current_doctor, doctor_has_access, require_doctor, require_record_reader
from ..models import Patient, Surgery
from ..schemas import SurgeryIn, SurgeryRescheduleIn, SurgeryUpdateIn, surgery_out
from ..services.records import audit, notify

router = APIRouter(tags=["surgeries"])


def _owned_surgery(db: Session, current: CurrentUser, surgery_id: str) -> Surgery:
    s = db.get(Surgery, surgery_id)
    if s is None:
        raise errors.not_found("Surgery")
    doctor = current_doctor(db, current)
    if not doctor_has_access(db, doctor.id, s.patient_id):
        raise errors.forbidden("You don't have access to this patient's records.")
    return s


def _require_scheduled(s: Surgery) -> None:
    if s.status != "scheduled":
        raise errors.conflict("This surgery is no longer scheduled.")


@router.post("/patients/{patient_id}/surgeries", status_code=201)
def create_surgery(patient_id: str, body: SurgeryIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    doctor = current_doctor(db, current)
    s = Surgery(
        patient_id=patient.id, doctor_id=doctor.id, doctor_name=current.name, name=body.name.strip(), purpose=body.purpose.strip(),
        scheduled_at=body.scheduled_at, hospital=body.hospital, patient_instructions=body.patient_instructions, internal_notes=body.internal_notes,
    )
    db.add(s)
    db.flush()
    when = f" on {body.scheduled_at:%d %b %Y}" if body.scheduled_at else ""
    notify(db, patient.user_id, "surgery_scheduled", "Surgery scheduled", f"Dr. {current.name} scheduled a surgery{when}: {s.name}.", "surgery", s.id, patient.id)
    audit(db, current, "surgery_scheduled", "surgery", s.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return surgery_out(s, include_internal=True)


@router.get("/patients/{patient_id}/surgeries")
def list_surgeries(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    rows = db.scalars(select(Surgery).where(Surgery.patient_id == patient.id).order_by(Surgery.scheduled_at))
    include_internal = current.role != "patient"
    return {"items": [surgery_out(s, include_internal=include_internal) for s in rows]}


@router.post("/surgeries/{surgery_id}/update")
def update_surgery(surgery_id: str, body: SurgeryUpdateIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    s = _owned_surgery(db, current, surgery_id)
    _require_scheduled(s)
    changed = body.model_dump(exclude_unset=True)
    for key, value in changed.items():
        setattr(s, key, value.strip() if isinstance(value, str) else value)
    s.updated_at = datetime.now(timezone.utc)
    patient = db.get(Patient, s.patient_id)
    audit(db, current, "surgery_updated", "surgery", s.id, None, {"patient_code": patient.patient_code, "fields": sorted(changed)})
    db.commit()
    return surgery_out(s, include_internal=True)


@router.post("/surgeries/{surgery_id}/reschedule")
def reschedule_surgery(surgery_id: str, body: SurgeryRescheduleIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    s = _owned_surgery(db, current, surgery_id)
    _require_scheduled(s)
    s.scheduled_at, s.updated_at = body.scheduled_at, datetime.now(timezone.utc)
    patient = db.get(Patient, s.patient_id)
    notify(db, patient.user_id, "surgery_rescheduled", "Surgery rescheduled", f"Dr. {current.name} moved your surgery ({s.name}) to {body.scheduled_at:%d %b %Y, %I:%M %p}.", "surgery", s.id, s.patient_id)
    audit(db, current, "surgery_rescheduled", "surgery", s.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return surgery_out(s, include_internal=True)


@router.post("/surgeries/{surgery_id}/complete")
def complete_surgery(surgery_id: str, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    s = _owned_surgery(db, current, surgery_id)
    _require_scheduled(s)
    s.status, s.updated_at = "completed", datetime.now(timezone.utc)
    patient = db.get(Patient, s.patient_id)
    audit(db, current, "surgery_completed", "surgery", s.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return surgery_out(s, include_internal=True)


@router.post("/surgeries/{surgery_id}/cancel")
def cancel_surgery(surgery_id: str, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    s = _owned_surgery(db, current, surgery_id)
    _require_scheduled(s)
    s.status, s.updated_at = "cancelled", datetime.now(timezone.utc)
    patient = db.get(Patient, s.patient_id)
    notify(db, patient.user_id, "surgery_cancelled", "Surgery cancelled", f"Dr. {current.name} cancelled the surgery planned for {s.name}.", "surgery", s.id, s.patient_id)
    audit(db, current, "surgery_cancelled", "surgery", s.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return surgery_out(s, include_internal=True)

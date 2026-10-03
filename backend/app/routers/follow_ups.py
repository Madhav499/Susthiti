"""Follow-up tasks: a doctor's "see this patient again by" reminder, tracked to completion.

Unlike Visit.follow_up_date / Prescription.follow_up_date -- informational notes on an
append-only clinical record, never marked done -- a FollowUp is scheduling state: it can be
completed, cancelled or rescheduled in place. Any doctor with approved access to the patient
may act on it, same as any other record in this patient's care (not restricted to whoever
created it)."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, current_doctor, doctor_has_access, require_doctor, require_record_reader
from ..models import FollowUp, Patient
from ..schemas import FollowUpActionIn, FollowUpIn, FollowUpRescheduleIn, follow_up_out
from ..services.records import audit, notify

router = APIRouter(tags=["follow-ups"])


def _owned_follow_up(db: Session, current: CurrentUser, follow_up_id: str) -> FollowUp:
    """A follow-up the current doctor may act on: it exists, and they have approved access
    to its patient."""
    f = db.get(FollowUp, follow_up_id)
    if f is None:
        raise errors.not_found("Follow-up")
    doctor = current_doctor(db, current)
    if not doctor_has_access(db, doctor.id, f.patient_id):
        raise errors.forbidden("You don't have access to this patient's records.")
    return f


def _require_scheduled(f: FollowUp) -> None:
    if f.status != "scheduled":
        raise errors.conflict("This follow-up is no longer scheduled.")


@router.post("/patients/{patient_id}/follow-ups", status_code=201)
def create_follow_up(patient_id: str, body: FollowUpIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    doctor = current_doctor(db, current)
    f = FollowUp(patient_id=patient.id, doctor_id=doctor.id, doctor_name=current.name, purpose=body.purpose.strip(), due_date=body.due_date)
    db.add(f)
    db.flush()
    notify(db, patient.user_id, "follow_up_scheduled", "Follow-up scheduled",
           f"Dr. {current.name} scheduled a follow-up for {body.due_date:%d %b %Y}: {f.purpose}", "follow_up", f.id, patient.id)
    audit(db, current, "follow_up_scheduled", "follow_up", f.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return follow_up_out(f)


@router.get("/patients/{patient_id}/follow-ups")
def list_follow_ups(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    rows = db.scalars(select(FollowUp).where(FollowUp.patient_id == patient.id).order_by(FollowUp.due_date))
    return {"items": [follow_up_out(f) for f in rows]}


@router.post("/follow-ups/{follow_up_id}/complete")
def complete_follow_up(follow_up_id: str, body: FollowUpActionIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    f = _owned_follow_up(db, current, follow_up_id)
    _require_scheduled(f)
    f.status, f.notes, f.updated_at = "completed", body.notes, datetime.now(timezone.utc)
    patient = db.get(Patient, f.patient_id)
    audit(db, current, "follow_up_completed", "follow_up", f.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return follow_up_out(f)


@router.post("/follow-ups/{follow_up_id}/cancel")
def cancel_follow_up(follow_up_id: str, body: FollowUpActionIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    f = _owned_follow_up(db, current, follow_up_id)
    _require_scheduled(f)
    f.status, f.notes, f.updated_at = "cancelled", body.notes, datetime.now(timezone.utc)
    patient = db.get(Patient, f.patient_id)
    notify(db, patient.user_id, "follow_up_cancelled", "Follow-up cancelled",
           f"Dr. {current.name} cancelled the follow-up planned for {f.due_date:%d %b %Y}.", "follow_up", f.id, f.patient_id)
    audit(db, current, "follow_up_cancelled", "follow_up", f.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return follow_up_out(f)


@router.post("/follow-ups/{follow_up_id}/reschedule")
def reschedule_follow_up(follow_up_id: str, body: FollowUpRescheduleIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    f = _owned_follow_up(db, current, follow_up_id)
    _require_scheduled(f)
    f.due_date, f.updated_at = body.due_date, datetime.now(timezone.utc)
    patient = db.get(Patient, f.patient_id)
    notify(db, patient.user_id, "follow_up_rescheduled", "Follow-up rescheduled",
           f"Dr. {current.name} moved your follow-up to {body.due_date:%d %b %Y}.", "follow_up", f.id, f.patient_id)
    audit(db, current, "follow_up_rescheduled", "follow_up", f.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return follow_up_out(f)

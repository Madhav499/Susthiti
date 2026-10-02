"""Side effects, doctor responses, appointment recommendations, visits and prescriptions.
All append-only: nothing here edits or deletes an earlier clinical record."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, current_doctor, require_clinical, require_record_reader, require_doctor, require_patient
from ..models import (
    AccessRequest,
    AppointmentRecommendation,
    Doctor,
    Patient,
    Prescription,
    PrescriptionItem,
    SideEffect,
    SideEffectEvent,
    Visit,
)
from ..schemas import (
    AppointmentIn,
    PrescriptionIn,
    SideEffectIn,
    SideEffectResponseIn,
    SideEffectStatusIn,
    VisitIn,
    appointment_out,
    prescription_out,
    side_effect_out,
    to_utc,
    visit_out,
)
from ..services.records import audit, next_code, notify

router = APIRouter(tags=["care"])

RESPONSE_LABELS = {
    "no_immediate_action": "No immediate action",
    "monitor": "Monitor",
    "contact_doctor": "Contact doctor",
    "appointment_recommended": "Appointment recommended",
    "urgent_medical_attention": "Urgent medical attention",
}


def _authorized_doctor_user_ids(db: Session, patient_id: str) -> list[str]:
    return list(db.scalars(
        select(Doctor.user_id).join(AccessRequest, AccessRequest.doctor_id == Doctor.id)
        .where(AccessRequest.patient_id == patient_id, AccessRequest.status == "approved")
    ))


# ---------- Side effects ----------

@router.post("/patients/{patient_id}/side-effects", status_code=201)
def report_side_effect(patient_id: str, body: SideEffectIn, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    # Rule-based prioritisation only (severity chosen by the patient). Clinical decision stays with the doctor.
    flagged = body.severity in ("severe", "emergency")
    effect = SideEffect(side_effect_code=next_code(db, "side_effect", "SE"), patient_id=patient.id, priority_flag=flagged, status="new", **body.model_dump())
    db.add(effect)
    db.flush()
    db.add(SideEffectEvent(side_effect_id=effect.id, actor_user_id=current.id, actor_name=current.name, actor_role="patient", status="new"))
    audit(db, current, "side_effect_reported", "side_effect", effect.id, effect.side_effect_code, {"severity": body.severity})
    for user_id in _authorized_doctor_user_ids(db, patient.id):
        notify(
            db, user_id, "new_side_effect", "New side-effect report",
            f"{patient.user.full_name} ({patient.patient_code}) reported a {body.severity} side effect.",
            "side_effect", effect.id, patient.id,
        )
    db.commit()
    return side_effect_out(effect, [])


@router.get("/patients/{patient_id}/side-effects")
def list_side_effects(
    patient_id: str, status: str | None = None, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    query = select(SideEffect).where(SideEffect.patient_id == patient.id)
    if status:
        query = query.where(SideEffect.status == status)
    rows = db.scalars(query.order_by(SideEffect.occurred_at.desc()).limit(limit).offset(offset))
    return {"items": [side_effect_out(s) for s in rows]}


def _authorized_side_effect(db: Session, current: CurrentUser, side_effect_id: str) -> tuple[SideEffect, Patient]:
    effect = db.get(SideEffect, side_effect_id)
    if effect is None:
        raise errors.not_found("Side effect")
    return effect, authorize_patient(db, current, effect.patient_id)


def _events(db: Session, effect_id: str):
    return list(db.scalars(select(SideEffectEvent).where(SideEffectEvent.side_effect_id == effect_id).order_by(SideEffectEvent.created_at)))


@router.get("/side-effects/{side_effect_id}")
def get_side_effect(side_effect_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    effect, _ = _authorized_side_effect(db, current, side_effect_id)
    return side_effect_out(effect, _events(db, effect.id))


@router.post("/side-effects/{side_effect_id}/status")
def set_side_effect_status(side_effect_id: str, body: SideEffectStatusIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    effect, _ = _authorized_side_effect(db, current, side_effect_id)
    effect.status = body.status
    db.add(SideEffectEvent(side_effect_id=effect.id, actor_user_id=current.id, actor_name=current.name, actor_role="doctor", status=body.status, message=body.message))
    audit(db, current, f"side_effect_{body.status}", "side_effect", effect.id, effect.side_effect_code)
    db.commit()
    return side_effect_out(effect, _events(db, effect.id))


@router.post("/side-effects/{side_effect_id}/responses", status_code=201)
def respond_side_effect(side_effect_id: str, body: SideEffectResponseIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    effect, patient = _authorized_side_effect(db, current, side_effect_id)
    doctor = current_doctor(db, current)
    status = "appointment_recommended" if body.response_type == "appointment_recommended" else "responded"
    effect.status = status
    db.add(SideEffectEvent(
        side_effect_id=effect.id, actor_user_id=current.id, actor_name=current.name, actor_role="doctor",
        status=status, response_type=body.response_type, message=body.message,
    ))
    if body.response_type == "appointment_recommended":
        db.add(AppointmentRecommendation(
            patient_id=patient.id, doctor_id=doctor.id, doctor_name=current.name, side_effect_id=effect.id,
            reason=body.appointment_reason or body.message or "Follow-up on reported side effect",
            recommended_for=to_utc(body.appointment_for) if body.appointment_for else None,
        ))
        notify(db, patient.user_id, "appointment_recommendation", "Appointment recommended",
               f"Dr. {current.name} recommends an appointment about your reported side effect.", "side_effect", effect.id, patient.id)
    notify(db, patient.user_id, "doctor_response", "Doctor responded",
           f"Dr. {current.name} responded to your side-effect report: {RESPONSE_LABELS[body.response_type]}.", "side_effect", effect.id, patient.id)
    audit(db, current, "side_effect_responded", "side_effect", effect.id, effect.side_effect_code, {"response_type": body.response_type})
    db.commit()
    return side_effect_out(effect, _events(db, effect.id))


# ---------- Appointment recommendations ----------

@router.post("/patients/{patient_id}/appointment-recommendations", status_code=201)
def recommend_appointment(patient_id: str, body: AppointmentIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    doctor = current_doctor(db, current)
    if body.side_effect_id:
        effect = db.get(SideEffect, body.side_effect_id)
        if effect is None or effect.patient_id != patient.id:
            raise errors.unprocessable("Side effect not found for this patient.")
    rec = AppointmentRecommendation(
        patient_id=patient.id, doctor_id=doctor.id, doctor_name=current.name, side_effect_id=body.side_effect_id,
        reason=body.reason, recommended_for=to_utc(body.recommended_for) if body.recommended_for else None,
    )
    db.add(rec)
    db.flush()
    notify(db, patient.user_id, "appointment_recommendation", "Appointment recommended", f"Dr. {current.name} recommends an appointment.", "appointment", rec.id, patient.id)
    audit(db, current, "appointment_recommended", "appointment", rec.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return appointment_out(rec)


@router.get("/patients/{patient_id}/appointment-recommendations")
def list_appointments(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    rows = db.scalars(select(AppointmentRecommendation).where(AppointmentRecommendation.patient_id == patient.id).order_by(AppointmentRecommendation.created_at.desc()))
    return {"items": [appointment_out(a) for a in rows]}


# ---------- Visits ----------

@router.post("/patients/{patient_id}/visits", status_code=201)
def create_visit(patient_id: str, body: VisitIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    doctor = current_doctor(db, current)
    visit = Visit(visit_code=next_code(db, "visit", "V"), patient_id=patient.id, doctor_id=doctor.id, doctor_name=current.name, **body.model_dump())
    db.add(visit)
    db.flush()
    audit(db, current, "visit_recorded", "visit", visit.id, visit.visit_code, {"patient_code": patient.patient_code})
    notify(db, patient.user_id, "visit_recorded", "Visit recorded", f"Dr. {current.name} recorded your visit on {body.visit_date:%d %b %Y}.", "visit", visit.id, patient.id)
    db.commit()
    return visit_out(visit)


@router.get("/patients/{patient_id}/visits")
def list_visits(patient_id: str, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0), current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    rows = db.scalars(select(Visit).where(Visit.patient_id == patient.id).order_by(Visit.visit_date.desc(), Visit.created_at.desc()).limit(limit).offset(offset))
    return {"items": [visit_out(v) for v in rows]}


@router.get("/visits/{visit_id}")
def get_visit(visit_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    visit = db.get(Visit, visit_id)
    if visit is None:
        raise errors.not_found("Visit")
    authorize_patient(db, current, visit.patient_id)
    return visit_out(visit)


# ---------- Prescriptions ----------

@router.post("/patients/{patient_id}/prescriptions", status_code=201)
def create_prescription(patient_id: str, body: PrescriptionIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    """Always creates a NEW prescription. Earlier prescriptions are never modified."""
    patient = authorize_patient(db, current, patient_id)
    doctor = current_doctor(db, current)
    rx = Prescription(
        prescription_code=next_code(db, "prescription", "RX"), patient_id=patient.id, doctor_id=doctor.id,
        doctor_name=current.name, prescribed_on=body.prescribed_on, instructions=body.instructions,
        notes=body.notes, follow_up_date=body.follow_up_date,
    )
    db.add(rx)
    db.flush()
    for position, med in enumerate(body.medicines):
        db.add(PrescriptionItem(prescription_id=rx.id, position=position, **med.model_dump()))
    db.flush()
    db.refresh(rx)
    audit(db, current, "prescription_created", "prescription", rx.id, rx.prescription_code, {"patient_code": patient.patient_code})
    notify(db, patient.user_id, "new_prescription", "New prescription", f"Dr. {current.name} created prescription {rx.prescription_code}.", "prescription", rx.id, patient.id)
    db.commit()
    return prescription_out(rx)


@router.get("/patients/{patient_id}/prescriptions")
def list_prescriptions(
    patient_id: str, q: str | None = Query(None, max_length=100), limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    query = select(Prescription).where(Prescription.patient_id == patient.id).options(selectinload(Prescription.items))
    if q:
        like = f"%{q.strip().lower()}%"
        query = query.where(or_(
            func.lower(Prescription.prescription_code).like(like), func.lower(Prescription.doctor_name).like(like),
            Prescription.id.in_(select(PrescriptionItem.prescription_id).where(func.lower(PrescriptionItem.medicine).like(like))),
        ))
    rows = db.scalars(query.order_by(Prescription.prescribed_on.desc(), Prescription.created_at.desc()).limit(limit).offset(offset))
    return {"items": [prescription_out(p) for p in rows]}


@router.get("/prescriptions/{prescription_id}")
def get_prescription(prescription_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    rx = db.get(Prescription, prescription_id)
    if rx is None:
        raise errors.not_found("Prescription")
    authorize_patient(db, current, rx.patient_id)
    return prescription_out(rx)

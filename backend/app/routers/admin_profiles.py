"""Admin read views of a doctor's or patient's complete system record.

All read-only. Clinical records themselves (reports, assessments, glucose, prescriptions...)
are read through the shared patient endpoints, which admit admins for reads only (see
deps.require_record_reader). Nothing here changes a record or its authorship.
"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, require_admin
from ..models import (
    AccessRequest,
    AISummary,
    AppointmentRecommendation,
    AuditLog,
    DiabetesAssessment,
    DiabetesRiskAssessment,
    Doctor,
    GlucoseReading,
    Notification,
    Patient,
    Prescription,
    Report,
    SideEffect,
    SideEffectEvent,
    Visit,
    WearableConnection,
)
from ..schemas import (
    access_out,
    appointment_out,
    doctor_out,
    iso,
    notification_out,
    patient_out,
    prescription_out,
    report_out,
    side_effect_out,
    summary_out,
    visit_out,
    wearable_out,
)
from ..services.health_data.body import body_measurements
from ..services.admin_views import (
    OPEN_SIDE_EFFECT_STATUSES,
    aware,
    latest_assessment,
    risk_brief,
    month_start,
    patient_brief,
    patient_last_activity,
    patient_record_ids,
    patient_snapshot,
    progress_summary,
    resolve_audit,
)
from ..services.records import audit

router = APIRouter(prefix="/admin", tags=["admin-profiles"])


def _doctor(db: Session, doctor_id: str) -> Doctor:
    doctor = db.get(Doctor, doctor_id)
    if doctor is None:
        raise errors.not_found("Doctor")
    return doctor


def _patient(db: Session, patient_id: str) -> Patient:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise errors.not_found("Patient")
    return patient


def _approved_patients(db: Session, doctor_id: str) -> list[Patient]:
    ids = select(AccessRequest.patient_id).where(AccessRequest.doctor_id == doctor_id, AccessRequest.status == "approved")
    return list(db.scalars(select(Patient).where(Patient.id.in_(ids))))


def _patients_by_id(db: Session, ids: set[str]) -> dict[str, Patient]:
    return {p.id: p for p in db.scalars(select(Patient).where(Patient.id.in_(ids)))} if ids else {}


# Sign-in and password events stay in the audit trail but are not "activity".
_SESSION_ACTIONS = ("login", "logout", "password_changed", "password_reset_requested", "password_reset_completed")


def doctor_last_activity(db: Session, doctor: Doctor) -> datetime | None:
    return aware(db.scalar(select(func.max(AuditLog.created_at)).where(AuditLog.actor_user_id == doctor.user_id, AuditLog.action.not_in(_SESSION_ACTIONS)))) or aware(doctor.user.last_login_at)


# ---------- Doctor profile ----------

@router.get("/doctors/{doctor_id}")
def doctor_profile(doctor_id: str, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Identity, status and a data-driven snapshot of the doctor's current workload."""
    doctor = _doctor(db, doctor_id)
    now = datetime.now(timezone.utc)
    today = now.date()
    since = month_start(now)
    count = lambda q: db.scalar(select(func.count()).select_from(q.subquery()))  # noqa: E731
    patients = _approved_patients(db, doctor.id)
    patient_ids = [p.id for p in patients]
    snapshots = [patient_snapshot(db, p, today) for p in patients]
    return {
        **doctor_out(doctor),
        "last_login_at": iso(doctor.user.last_login_at),
        "last_activity_at": iso(doctor_last_activity(db, doctor)),
        "stats": {
            "active_patients": len(patients),
            "total_patients": count(select(AccessRequest.patient_id).where(AccessRequest.doctor_id == doctor.id).distinct()),
            "pending_requests": count(select(AccessRequest.id).where(AccessRequest.doctor_id == doctor.id, AccessRequest.status == "pending")),
            "reports_uploaded": count(select(Report.id).where(Report.uploader_user_id == doctor.user_id)),
            "reports_uploaded_this_month": count(select(Report.id).where(Report.uploader_user_id == doctor.user_id, Report.uploaded_at >= since)),
            "prescriptions": count(select(Prescription.id).where(Prescription.doctor_id == doctor.id)),
            "prescriptions_this_month": count(select(Prescription.id).where(Prescription.doctor_id == doctor.id, Prescription.created_at >= since)),
            "visits": count(select(Visit.id).where(Visit.doctor_id == doctor.id)),
            "visits_this_month": count(select(Visit.id).where(Visit.doctor_id == doctor.id, Visit.created_at >= since)),
            "upcoming_appointments": count(select(AppointmentRecommendation.id).where(AppointmentRecommendation.doctor_id == doctor.id, AppointmentRecommendation.recommended_for >= now)),
            "upcoming_follow_ups": count(select(Visit.id).where(Visit.doctor_id == doctor.id, Visit.follow_up_date >= today))
            + count(select(Prescription.id).where(Prescription.doctor_id == doctor.id, Prescription.follow_up_date >= today)),
            "side_effects_pending": count(select(SideEffect.id).where(SideEffect.patient_id.in_(patient_ids), SideEffect.status.in_(OPEN_SIDE_EFFECT_STATUSES))) if patient_ids else 0,
            "side_effects_resolved": count(select(SideEffect.id).where(SideEffect.patient_id.in_(patient_ids), SideEffect.status == "resolved")) if patient_ids else 0,
            "side_effects_responded": count(select(SideEffectEvent.side_effect_id).where(SideEffectEvent.actor_user_id == doctor.user_id).distinct()),
        },
        "progress": progress_summary(snapshots),
    }


@router.get("/doctors/{doctor_id}/patients")
def doctor_patients(doctor_id: str, status: str = Query("all", pattern="^(all|approved|pending|rejected|revoked)$"),
                    current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Every patient relationship of this doctor. Approved ones carry a full current snapshot."""
    doctor = _doctor(db, doctor_id)
    query = select(AccessRequest).where(AccessRequest.doctor_id == doctor.id)
    if status != "all":
        query = query.where(AccessRequest.status == status)
    today = datetime.now(timezone.utc).date()
    items = []
    for req in db.scalars(query.order_by(AccessRequest.created_at.desc())):
        snapshot = patient_snapshot(db, req.patient, today) if req.status == "approved" else {**patient_brief(req.patient), "last_activity_at": iso(patient_last_activity(db, req.patient))}
        items.append({**access_out(req), "patient": snapshot})
    return {"items": items}


@router.get("/doctors/{doctor_id}/reports")
def doctor_reports(doctor_id: str, limit: int = Query(30, ge=1, le=100), current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Reports the doctor uploaded, reports they opened, and report summaries they generated."""
    doctor = _doctor(db, doctor_id)
    uploaded = list(db.scalars(select(Report).where(Report.uploader_user_id == doctor.user_id).order_by(Report.uploaded_at.desc()).limit(limit)))
    opened_logs = list(db.scalars(
        select(AuditLog).where(AuditLog.actor_user_id == doctor.user_id, AuditLog.action == "report_file_accessed").order_by(AuditLog.created_at.desc()).limit(limit)
    ))
    opened_reports = {r.id: r for r in db.scalars(select(Report).where(Report.id.in_({a.entity_id for a in opened_logs})))} if opened_logs else {}
    summaries = list(db.scalars(
        select(AISummary).where(AISummary.generated_by_user_id == doctor.user_id, AISummary.kind.in_(["individual_report", "all_reports"]))
        .order_by(AISummary.generated_at.desc()).limit(limit)
    ))
    patients = _patients_by_id(db, {r.patient_id for r in uploaded} | {r.patient_id for r in opened_reports.values()} | {s.patient_id for s in summaries})

    def with_patient(out: dict, patient_id: str) -> dict:
        p = patients.get(patient_id)
        return {**out, "patient": patient_brief(p) if p else None}

    return {
        "uploaded": [with_patient(report_out(r), r.patient_id) for r in uploaded],
        "opened": [
            with_patient({**report_out(opened_reports[a.entity_id]), "opened_at": iso(a.created_at)}, opened_reports[a.entity_id].patient_id)
            for a in opened_logs if a.entity_id in opened_reports
        ],
        "summaries": [
            with_patient({"id": s.id, "kind": s.kind, "subject_id": s.subject_id, "generated_at": iso(s.generated_at), "model": s.model}, s.patient_id)
            for s in summaries
        ],
    }


@router.get("/doctors/{doctor_id}/prescriptions")
def doctor_prescriptions(doctor_id: str, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
                         current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    doctor = _doctor(db, doctor_id)
    query = select(Prescription).where(Prescription.doctor_id == doctor.id)
    total = db.scalar(select(func.count()).select_from(query.subquery()))
    rows = list(db.scalars(query.options(selectinload(Prescription.items)).order_by(Prescription.prescribed_on.desc(), Prescription.created_at.desc()).limit(limit).offset(offset)))
    patients = _patients_by_id(db, {p.patient_id for p in rows})
    return {
        "total": total,
        "items": [{**prescription_out(p), "patient": patient_brief(patients[p.patient_id]) if p.patient_id in patients else None} for p in rows],
    }


@router.get("/doctors/{doctor_id}/appointments")
def doctor_appointments(doctor_id: str, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Appointment recommendations the doctor made, upcoming follow-ups from their visits and
    prescriptions, and their recent visits. Only stored dates; nothing is scheduled here."""
    doctor = _doctor(db, doctor_id)
    today = datetime.now(timezone.utc).date()
    recs = list(db.scalars(select(AppointmentRecommendation).where(AppointmentRecommendation.doctor_id == doctor.id).order_by(AppointmentRecommendation.created_at.desc()).limit(50)))
    visits = list(db.scalars(select(Visit).where(Visit.doctor_id == doctor.id).order_by(Visit.visit_date.desc()).limit(30)))
    due_visits = list(db.scalars(select(Visit).where(Visit.doctor_id == doctor.id, Visit.follow_up_date >= today)))
    due_rx = list(db.scalars(select(Prescription).where(Prescription.doctor_id == doctor.id, Prescription.follow_up_date >= today)))
    patients = _patients_by_id(db, {r.patient_id for r in recs} | {v.patient_id for v in visits + due_visits} | {p.patient_id for p in due_rx})

    def brief(pid: str):
        return patient_brief(patients[pid]) if pid in patients else None

    follow_ups = [
        {"date": iso(v.follow_up_date), "source": "visit", "record_id": v.id, "code": v.visit_code, "reason": v.reason, "patient": brief(v.patient_id)} for v in due_visits
    ] + [
        {"date": iso(p.follow_up_date), "source": "prescription", "record_id": p.id, "code": p.prescription_code, "reason": None, "patient": brief(p.patient_id)} for p in due_rx
    ]
    follow_ups.sort(key=lambda f: f["date"])
    return {
        "recommendations": [{**appointment_out(r), "patient": brief(r.patient_id)} for r in recs],
        "follow_ups": follow_ups,
        "visits": [
            {"id": v.id, "visit_code": v.visit_code, "visit_date": iso(v.visit_date), "reason": v.reason, "follow_up_date": iso(v.follow_up_date), "patient": brief(v.patient_id)}
            for v in visits
        ],
    }


@router.get("/doctors/{doctor_id}/side-effects")
def doctor_side_effects(doctor_id: str, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Side effects from the doctor's current patients plus any the doctor has responded to."""
    doctor = _doctor(db, doctor_id)
    patient_ids = [p.id for p in _approved_patients(db, doctor.id)]
    responded_ids = set(db.scalars(select(SideEffectEvent.side_effect_id).where(SideEffectEvent.actor_user_id == doctor.user_id)))
    conditions = [SideEffect.id.in_(responded_ids)] if responded_ids else []
    if patient_ids:
        conditions.append(SideEffect.patient_id.in_(patient_ids))
    if not conditions:
        return {"items": [], "pending": 0, "resolved": 0}
    rows = list(db.scalars(select(SideEffect).where(or_(*conditions)).order_by(SideEffect.occurred_at.desc()).limit(100)))
    patients = _patients_by_id(db, {s.patient_id for s in rows})
    last_response = {}
    for e in db.scalars(select(SideEffectEvent).where(SideEffectEvent.side_effect_id.in_([s.id for s in rows]), SideEffectEvent.actor_user_id == doctor.user_id).order_by(SideEffectEvent.created_at)):
        last_response[e.side_effect_id] = e
    return {
        "items": [
            {
                **side_effect_out(s),
                "patient": patient_brief(patients[s.patient_id]) if s.patient_id in patients else None,
                "doctor_response": None if s.id not in last_response else {
                    "response_type": last_response[s.id].response_type, "status": last_response[s.id].status, "created_at": iso(last_response[s.id].created_at),
                },
            }
            for s in rows
        ],
        "pending": sum(1 for s in rows if s.status in OPEN_SIDE_EFFECT_STATUSES),
        "resolved": sum(1 for s in rows if s.status == "resolved"),
    }


@router.get("/doctors/{doctor_id}/activity")
def doctor_activity(doctor_id: str, scope: str = Query("actions", pattern="^(actions|audit)$"),
                    limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
                    current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """actions: what the doctor did. audit: that, plus changes made to the doctor's account and
    access requests involving the doctor."""
    doctor = _doctor(db, doctor_id)
    if scope == "actions":
        query = select(AuditLog).where(AuditLog.actor_user_id == doctor.user_id, AuditLog.action.not_in(_SESSION_ACTIONS))
    else:
        request_ids = select(AccessRequest.id).where(AccessRequest.doctor_id == doctor.id)
        query = select(AuditLog).where(or_(
            AuditLog.actor_user_id == doctor.user_id,
            (AuditLog.entity_type == "doctor") & (AuditLog.entity_id == doctor.id),
            (AuditLog.entity_type == "access_request") & AuditLog.entity_id.in_(request_ids),
            (AuditLog.entity_type == "user") & (AuditLog.entity_id == doctor.user_id),
        ))
    total = db.scalar(select(func.count()).select_from(query.subquery()))
    rows = list(db.scalars(query.order_by(AuditLog.created_at.desc()).limit(limit).offset(offset)))
    return {"items": resolve_audit(db, rows), "total": total}


# ---------- Patient profile ----------

@router.get("/patients/{patient_id}")
def patient_profile(patient_id: str, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """The patient's system record: identity, account, current state, doctors and record counts.
    Opening it is audited, because it is the entry point to the patient's medical data."""
    patient = _patient(db, patient_id)
    latest = latest_assessment(db, patient.id)
    count = lambda model: db.scalar(select(func.count(model.id)).where(model.patient_id == patient.id))  # noqa: E731
    snapshot = patient_snapshot(db, patient)
    audit(db, current, "patient_record_viewed", "patient", patient.id, patient.patient_code)
    db.commit()
    return {
        **patient_out(patient, body_measurements(db, patient.id)),
        "last_login_at": iso(patient.user.last_login_at),
        "last_activity_at": snapshot["last_activity_at"],
        "latest_assessment": risk_brief(latest),
        "latest_glucose": snapshot["latest_glucose"],
        "glucose_average_7d": snapshot["glucose_average_7d"],
        "glucose_trend": snapshot["glucose_trend"],
        "next_follow_up": snapshot["next_follow_up"],
        "open_side_effects": snapshot["open_side_effects"],
        "attention": snapshot["attention"],
        "doctors": [access_out(a) for a in db.scalars(select(AccessRequest).where(AccessRequest.patient_id == patient.id).order_by(AccessRequest.created_at.desc()))],
        "counts": {
            "reports": count(Report), "assessments": count(DiabetesRiskAssessment), "earlier_model_assessments": count(DiabetesAssessment),
            "glucose_readings": count(GlucoseReading),
            "prescriptions": count(Prescription), "visits": count(Visit), "side_effects": count(SideEffect),
            "appointments": count(AppointmentRecommendation), "ai_summaries": count(AISummary),
        },
    }


@router.get("/patients/{patient_id}/devices")
def patient_devices(patient_id: str, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """All wearable connections, including disconnected ones (kept for history)."""
    patient = _patient(db, patient_id)
    rows = db.scalars(select(WearableConnection).where(WearableConnection.patient_id == patient.id).order_by(WearableConnection.created_at.desc()))
    return {"items": [wearable_out(w) for w in rows]}


@router.get("/patients/{patient_id}/notifications")
def patient_notifications(patient_id: str, limit: int = Query(50, ge=1, le=200), current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    patient = _patient(db, patient_id)
    rows = db.scalars(select(Notification).where(Notification.user_id == patient.user_id).order_by(Notification.created_at.desc()).limit(limit))
    return {"items": [notification_out(n) for n in rows]}


@router.get("/patients/{patient_id}/ai-summaries")
def patient_ai_summaries(patient_id: str, limit: int = Query(50, ge=1, le=200), current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Every stored AI generation for the patient, newest first (history is never overwritten)."""
    patient = _patient(db, patient_id)
    rows = db.scalars(select(AISummary).where(AISummary.patient_id == patient.id).order_by(AISummary.generated_at.desc()).limit(limit))
    return {"items": [summary_out(s) for s in rows]}


@router.get("/patients/{patient_id}/audit")
def patient_audit(patient_id: str, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
                  current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Everything done by or to this patient, including actions on any of their records."""
    patient = _patient(db, patient_id)
    query = select(AuditLog).where(or_(AuditLog.entity_id.in_(patient_record_ids(db, patient)), AuditLog.actor_user_id == patient.user_id))
    total = db.scalar(select(func.count()).select_from(query.subquery()))
    rows = list(db.scalars(query.order_by(AuditLog.created_at.desc()).limit(limit).offset(offset)))
    return {"items": resolve_audit(db, rows), "total": total}

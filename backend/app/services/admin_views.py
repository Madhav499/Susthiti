"""Read models for the admin's doctor and patient profiles.

Everything here is derived from stored records. There is no health score: patient "progress"
is shown as the same factual signals clinicians already see (latest model classification,
glucose direction versus previous weeks, open side effects, due follow-ups, recent activity).
"""

from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import (
    AccessRequest,
    AISummary,
    AppointmentRecommendation,
    AuditLog,
    DiabetesAssessment,
    DiabetesRiskAssessment,
    Doctor,
    FoodEntry,
    GlucoseReading,
    HeartRiskAssessment,
    Patient,
    Prescription,
    Report,
    SideEffect,
    Visit,
    WearableConnection,
)
from ..schemas import age_from, audit_out, iso
from .lifestyle_data import glucose_overview

OPEN_SIDE_EFFECT_STATUSES = ("new", "under_review")


def aware(dt: datetime | None) -> datetime | None:
    """SQLite drops tzinfo; stored times are UTC."""
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def month_start(now: datetime | None = None) -> datetime:
    now = now or datetime.now(timezone.utc)
    return datetime(now.year, now.month, 1, tzinfo=timezone.utc)


def latest_assessment(db: Session, patient_id: str) -> DiabetesRiskAssessment | None:
    """The latest future diabetes risk estimate (the current model)."""
    return db.scalar(
        select(DiabetesRiskAssessment).where(DiabetesRiskAssessment.patient_id == patient_id).order_by(DiabetesRiskAssessment.created_at.desc()).limit(1)
    )


def risk_brief(a: DiabetesRiskAssessment | None) -> dict | None:
    if a is None:
        return None
    return {
        "id": a.id, "assessment_code": a.assessment_code, "risk_percent": a.risk_percent, "risk_category": a.risk_category,
        "prediction": a.prediction, "prediction_label": a.prediction_label, "report_available": a.report_available,
        "assessed_at": iso(a.created_at), "model_version": a.model_version,
    }


def latest_heart_assessment(db: Session, patient_id: str) -> HeartRiskAssessment | None:
    """The latest heart disease risk screening result (synthetic-data model, a screening
    signal, never a diagnosis)."""
    return db.scalar(
        select(HeartRiskAssessment).where(HeartRiskAssessment.patient_id == patient_id).order_by(HeartRiskAssessment.created_at.desc()).limit(1)
    )


def heart_brief(a: HeartRiskAssessment | None) -> dict | None:
    if a is None:
        return None
    return {
        "id": a.id, "assessment_code": a.assessment_code, "probability_percent": a.probability_percent, "risk_level": a.risk_level,
        "prediction": a.prediction, "prediction_label": a.prediction_label, "report_available": a.report_available,
        "assessed_at": iso(a.created_at), "model_version": a.model_version,
    }


def patient_last_activity(db: Session, p: Patient) -> datetime | None:
    """Most recent sign-in or record entry by anyone."""
    candidates = [
        p.user.last_login_at,
        db.scalar(select(func.max(Report.uploaded_at)).where(Report.patient_id == p.id)),
        db.scalar(select(func.max(DiabetesAssessment.assessed_at)).where(DiabetesAssessment.patient_id == p.id)),
        db.scalar(select(func.max(DiabetesRiskAssessment.created_at)).where(DiabetesRiskAssessment.patient_id == p.id)),
        db.scalar(select(func.max(HeartRiskAssessment.created_at)).where(HeartRiskAssessment.patient_id == p.id)),
        db.scalar(select(func.max(GlucoseReading.created_at)).where(GlucoseReading.patient_id == p.id)),
        db.scalar(select(func.max(FoodEntry.created_at)).where(FoodEntry.patient_id == p.id)),
        db.scalar(select(func.max(SideEffect.created_at)).where(SideEffect.patient_id == p.id)),
        db.scalar(select(func.max(Prescription.created_at)).where(Prescription.patient_id == p.id)),
        db.scalar(select(func.max(Visit.created_at)).where(Visit.patient_id == p.id)),
    ]
    return max((aware(d) for d in candidates if d is not None), default=None)


def next_follow_up(db: Session, patient_id: str, today: date, doctor_id: str | None = None) -> date | None:
    visit_q = select(func.min(Visit.follow_up_date)).where(Visit.patient_id == patient_id, Visit.follow_up_date >= today)
    rx_q = select(func.min(Prescription.follow_up_date)).where(Prescription.patient_id == patient_id, Prescription.follow_up_date >= today)
    if doctor_id:
        visit_q = visit_q.where(Visit.doctor_id == doctor_id)
        rx_q = rx_q.where(Prescription.doctor_id == doctor_id)
    dates = [d for d in (db.scalar(visit_q), db.scalar(rx_q)) if d]
    return min(dates) if dates else None


def attention_reasons(db: Session, patient_id: str, today: date) -> list[dict]:
    """Same rules as the doctor dashboard: open side effects, follow-up due within 7 days,
    and reports uploaded in the last 7 days."""
    reasons = []
    for s in db.scalars(select(SideEffect).where(SideEffect.patient_id == patient_id, SideEffect.status.in_(OPEN_SIDE_EFFECT_STATUSES)).order_by(SideEffect.created_at.desc())):
        reasons.append({"reason": f"{s.severity.capitalize()} side effect reported", "at": iso(s.created_at), "entity_type": "side_effect", "entity_id": s.id})
    due = next_follow_up(db, patient_id, today)
    if due and due <= today + timedelta(days=7):
        reasons.append({"reason": f"Follow-up due {due:%d %b}", "at": iso(due), "entity_type": "patient", "entity_id": patient_id})
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    for r in db.scalars(select(Report).where(Report.patient_id == patient_id, Report.uploaded_at >= week_ago).order_by(Report.uploaded_at.desc()).limit(3)):
        reasons.append({"reason": "New report", "at": iso(r.uploaded_at), "entity_type": "report", "entity_id": r.id})
    return reasons


def patient_brief(p: Patient) -> dict:
    return {"id": p.id, "name": p.user.full_name, "patient_code": p.patient_code, "is_active": p.user.is_active}


def patient_snapshot(db: Session, p: Patient, today: date | None = None) -> dict:
    """Current state of one patient, from stored records only."""
    today = today or datetime.now(timezone.utc).date()
    latest = latest_assessment(db, p.id)
    latest_heart = latest_heart_assessment(db, p.id)
    glucose = glucose_overview(db, p.id, today)
    return {
        **patient_brief(p),
        "age": age_from(p.date_of_birth),
        "gender": p.gender,
        "is_demo": p.user.is_demo,
        "latest_assessment": risk_brief(latest),
        "latest_heart_assessment": heart_brief(latest_heart),
        "latest_glucose": glucose["latest"],
        "glucose_average_7d": glucose["recent_average_7d"],
        "glucose_trend": glucose["trend_vs_previous_weeks"],
        "last_activity_at": iso(patient_last_activity(db, p)),
        "next_follow_up": iso(next_follow_up(db, p.id, today)),
        "open_side_effects": db.scalar(select(func.count(SideEffect.id)).where(SideEffect.patient_id == p.id, SideEffect.status.in_(OPEN_SIDE_EFFECT_STATUSES))),
        "attention": attention_reasons(db, p.id, today),
    }


def progress_summary(snapshots: list[dict]) -> dict:
    """Counts of factual signals across a set of patients (no derived score)."""
    thirty_days_ago = datetime.now(timezone.utc) - timedelta(days=30)

    def recent(value: str | None) -> bool:
        return value is not None and aware(datetime.fromisoformat(value)) >= thirty_days_ago

    def latest(s: dict, key: str):
        return (s["latest_assessment"] or {}).get(key)

    return {
        "patients": len(snapshots),
        # The model's own 50% decision (Higher- / Lower-risk pattern), as the API returned it.
        "elevated_risk_pattern": sum(1 for s in snapshots if latest(s, "prediction") == 1),
        "lower_risk_pattern": sum(1 for s in snapshots if latest(s, "prediction") == 0),
        "high_risk_band": sum(1 for s in snapshots if latest(s, "risk_category") == "High"),
        "moderate_risk_band": sum(1 for s in snapshots if latest(s, "risk_category") == "Moderate"),
        "low_risk_band": sum(1 for s in snapshots if latest(s, "risk_category") == "Low"),
        "not_assessed": sum(1 for s in snapshots if s["latest_assessment"] is None),
        "needs_attention": sum(1 for s in snapshots if s["attention"]),
        "open_side_effects": sum(1 for s in snapshots if s["open_side_effects"]),
        "assessed_last_30d": sum(1 for s in snapshots if s["latest_assessment"] and recent(s["latest_assessment"]["assessed_at"])),
        "glucose_higher": sum(1 for s in snapshots if s["glucose_trend"] == "higher"),
        "glucose_lower": sum(1 for s in snapshots if s["glucose_trend"] == "lower"),
        "glucose_stable": sum(1 for s in snapshots if s["glucose_trend"] == "stable"),
        "no_activity_30d": sum(1 for s in snapshots if not recent(s["last_activity_at"])),
    }


# Audit entries point at a record; resolve which patient (and doctor) each one concerns so the
# admin can open it.
_PATIENT_OWNED = {
    "report": Report,
    "assessment": DiabetesAssessment,
    "diabetes_risk": DiabetesRiskAssessment,
    "heart_risk": HeartRiskAssessment,
    "side_effect": SideEffect,
    "visit": Visit,
    "prescription": Prescription,
    "ai_summary": AISummary,
    "access_request": AccessRequest,
    "appointment": AppointmentRecommendation,
    "wearable": WearableConnection,
}


def resolve_audit(db: Session, logs: list[AuditLog]) -> list[dict]:
    patient_of: dict[tuple[str, str], str] = {}
    doctor_of: dict[tuple[str, str], str] = {}
    by_type: dict[str, set[str]] = {}
    for a in logs:
        if a.entity_type and a.entity_id:
            by_type.setdefault(a.entity_type, set()).add(a.entity_id)
    for entity_type, ids in by_type.items():
        model = _PATIENT_OWNED.get(entity_type)
        if model is not None:
            for row in db.scalars(select(model).where(model.id.in_(ids))):
                patient_of[(entity_type, row.id)] = row.patient_id
                if getattr(row, "doctor_id", None):
                    doctor_of[(entity_type, row.id)] = row.doctor_id
        elif entity_type == "patient":
            for pid in ids:
                patient_of[("patient", pid)] = pid
        elif entity_type == "doctor":
            for did in ids:
                doctor_of[("doctor", did)] = did
    patients = {p.id: p for p in db.scalars(select(Patient).where(Patient.id.in_(set(patient_of.values()))))} if patient_of else {}
    doctors = {d.id: d for d in db.scalars(select(Doctor).where(Doctor.id.in_(set(doctor_of.values()))))} if doctor_of else {}
    out = []
    for a in logs:
        key = (a.entity_type or "", a.entity_id or "")
        p = patients.get(patient_of.get(key, ""))
        d = doctors.get(doctor_of.get(key, ""))
        out.append({
            **audit_out(a),
            "patient": patient_brief(p) if p else None,
            "doctor": {"id": d.id, "name": d.user.full_name, "doctor_code": d.doctor_code} if d else None,
        })
    return out


def patient_record_ids(db: Session, patient: Patient) -> set[str]:
    """Ids of every record belonging to the patient, for matching audit entries."""
    ids = {patient.id, patient.user_id}
    for model in _PATIENT_OWNED.values():
        ids.update(db.scalars(select(model.id).where(model.patient_id == patient.id)))
    return ids

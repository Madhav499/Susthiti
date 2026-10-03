from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, File, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, current_patient, get_current_user, require_clinical, require_record_reader, require_patient
from ..models import (
    AISummary,
    AppointmentRecommendation,
    DiabetesAssessment,
    DiabetesRiskAssessment,
    FollowUp,
    Notification,
    Prescription,
    Report,
    ReportValue,
    SideEffect,
    Surgery,
    Visit,
)
from ..schemas import PatientProfileIn, appointment_out, follow_up_out, iso, patient_out, report_out, surgery_out
from ..services.diabetes_risk import coordinator as risk_coordinator
from ..services.diabetes_risk import presentation as risk_presentation
from ..services.health_data import report_values as rv
from ..services.health_data.body import body_measurements, is_birthday, local_today
from ..services.lifestyle_data import daily_series, glucose_overview, metric_overview
from ..services.records import audit
from ..services.storage import ALLOWED_PHOTO_TYPES, get_storage, sniff_content_type

router = APIRouter(tags=["patients"])

MAX_PHOTO_BYTES = 5 * 1024 * 1024


@router.get("/patients/me")
def my_profile(current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    patient = current_patient(db, current)
    return patient_out(patient, body_measurements(db, patient.id))


@router.patch("/patients/me")
def update_my_profile(body: PatientProfileIn, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    """Profile/contact details (not medical records) can be updated."""
    patient = current_patient(db, current)
    data = body.model_dump(exclude_unset=True)
    if "full_name" in data and data["full_name"]:
        patient.user.full_name = data.pop("full_name").strip()
    for key, value in data.items():
        setattr(patient, key, value)
    audit(db, current, "profile_updated", "patient", patient.id, patient.patient_code, {"fields": sorted(body.model_fields_set)})
    db.commit()
    return patient_out(patient, body_measurements(db, patient.id))


@router.put("/patients/me/photo")
async def upload_photo(file: UploadFile = File(...), current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    patient = current_patient(db, current)
    data = await file.read(MAX_PHOTO_BYTES + 1)
    if len(data) > MAX_PHOTO_BYTES:
        raise errors.unprocessable("Photo must be 5 MB or smaller.")
    content_type = sniff_content_type(data, file.filename or "", file.content_type)
    if content_type not in ALLOWED_PHOTO_TYPES:
        raise errors.unprocessable("Photo must be a JPEG, PNG or WebP image.")
    patient.photo_ref = get_storage().save("photos", data, ALLOWED_PHOTO_TYPES[content_type])
    audit(db, current, "profile_photo_updated", "patient", patient.id, patient.patient_code)
    db.commit()
    return patient_out(patient, body_measurements(db, patient.id))


@router.get("/patients/{patient_id}/photo")
def get_photo(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    if not patient.photo_ref:
        raise errors.not_found("Photo")
    data = get_storage().read(patient.photo_ref)
    return Response(data, media_type=sniff_content_type(data, "", None) or "application/octet-stream", headers={"Cache-Control": "private, no-store"})


@router.get("/patients/{patient_id}/profile")
def patient_profile(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    return patient_out(patient, body_measurements(db, patient.id))


@router.get("/patients/{patient_id}/dashboard")
def dashboard(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    latest_risk = risk_coordinator.latest(db, patient.id)
    risk_reasons = risk_coordinator.stale_reasons(latest_risk, risk_coordinator.evaluate(db, patient)[1]) if latest_risk else []
    reports = db.scalars(select(Report).where(Report.patient_id == patient.id).order_by(Report.report_date.desc(), Report.uploaded_at.desc()).limit(3))
    insight = db.scalar(
        select(AISummary).where(AISummary.patient_id == patient.id, AISummary.kind == "lifestyle").order_by(AISummary.generated_at.desc()).limit(1)
    )
    unread = db.scalar(select(Notification.id).where(Notification.user_id == current.id, Notification.is_read.is_(False)).limit(1))

    # The one appointment recommendation most worth showing right now: the soonest future-dated
    # one, or else the most recently made one still waiting to be scheduled.
    now = datetime.now(timezone.utc)
    appts = list(db.scalars(select(AppointmentRecommendation).where(AppointmentRecommendation.patient_id == patient.id)))

    def _at(a: AppointmentRecommendation) -> datetime | None:
        rf = a.recommended_for
        return rf if rf is None or rf.tzinfo else rf.replace(tzinfo=timezone.utc)

    future = sorted((a for a in appts if _at(a) is not None and _at(a) >= now), key=_at)
    next_appt = future[0] if future else None
    if next_appt is None:
        undated = sorted((a for a in appts if a.recommended_for is None), key=lambda a: a.created_at, reverse=True)
        next_appt = undated[0] if undated else None

    # The soonest follow-up still scheduled (not completed or cancelled).
    next_follow_up = db.scalar(
        select(FollowUp).where(FollowUp.patient_id == patient.id, FollowUp.status == "scheduled").order_by(FollowUp.due_date).limit(1)
    )

    # The soonest surgery still scheduled.
    next_surgery = db.scalar(
        select(Surgery).where(Surgery.patient_id == patient.id, Surgery.status == "scheduled").order_by(Surgery.scheduled_at).limit(1)
    )

    return {
        "patient": {"id": patient.id, "name": patient.user.full_name, "patient_code": patient.patient_code,
                    "date_of_birth": iso(patient.date_of_birth), "is_birthday": is_birthday(patient.date_of_birth, local_today())},
        "diabetes_risk": {
            "latest": None if latest_risk is None else risk_presentation.assessment_summary(latest_risk),
            "stale": bool(risk_reasons), "stale_reasons": risk_reasons,
        },
        "glucose": glucose_overview(db, patient.id),
        "metrics": {m: metric_overview(db, patient.id, m) for m in ("steps", "sleep", "activity", "heart_rate")},
        "recent_reports": [report_out(r) for r in reports],
        "lifestyle_insight": None if insight is None else {"id": insight.id, "headline": insight.content.get("headline"), "generated_at": iso(insight.generated_at)},
        "has_unread_notifications": unread is not None,
        "next_appointment": None if next_appt is None else appointment_out(next_appt),
        "next_follow_up": None if next_follow_up is None else follow_up_out(next_follow_up),
        "next_surgery": None if next_surgery is None else surgery_out(next_surgery, include_internal=False),
    }


RANGES = {"7d": 7, "30d": 30, "1m": 30, "3m": 90, "6m": 182, "1y": 365}


def resolve_range(range_: str, start: date | None, end: date | None) -> tuple[date, date]:
    today = datetime.now(timezone.utc).date()
    if range_ == "custom":
        if not start or not end or start > end:
            raise errors.unprocessable("Choose a valid start and end date.")
        if (end - start).days > 3 * 366:
            raise errors.unprocessable("Custom range can be at most 3 years.")
        return start, end
    if range_ not in RANGES:
        raise errors.unprocessable("Unknown range.")
    return today - timedelta(days=RANGES[range_] - 1), today


@router.get("/patients/{patient_id}/trends")
def trends(
    patient_id: str,
    metric: str = Query(...),
    range: str = Query("30d"),
    start: date | None = None,
    end: date | None = None,
    current: CurrentUser = Depends(require_record_reader),
    db: Session = Depends(get_db),
):
    """Actual recorded values per day. No health score, no interpolation."""
    patient = authorize_patient(db, current, patient_id)
    start_d, end_d = resolve_range(range, start, end)
    if metric == "glucose":
        from ..models import GlucoseReading
        from ..services.lifestyle_data import to_mg_dl

        rows = db.scalars(select(GlucoseReading).where(
            GlucoseReading.patient_id == patient.id,
            GlucoseReading.measured_at >= datetime(start_d.year, start_d.month, start_d.day, tzinfo=timezone.utc),
            GlucoseReading.measured_at < datetime(end_d.year, end_d.month, end_d.day, tzinfo=timezone.utc) + timedelta(days=1),
        ).order_by(GlucoseReading.measured_at))
        points = [{"date": iso(r.measured_at), "value": to_mg_dl(r.value, r.unit), "reading_type": r.reading_type, "is_demo": r.is_demo} for r in rows]
        return {"metric": "glucose", "unit": "mg/dL", "start": iso(start_d), "end": iso(end_d), "points": points}
    analyte = rv.ANALYTES.get(metric)
    if analyte is not None and analyte.kind == "number":
        # Confirmed report values only -- never a value still waiting for someone to confirm it,
        # never a superseded or removed one.
        rows = db.scalars(select(ReportValue).where(
            ReportValue.patient_id == patient.id, ReportValue.analyte == metric,
            ReportValue.superseded_at.is_(None), ReportValue.removed.is_(False),
            ReportValue.measured_on >= start_d, ReportValue.measured_on <= end_d,
        ).order_by(ReportValue.measured_on))
        points = [{"date": iso(r.measured_on), "value": r.value} for r in rows]
        return {"metric": metric, "unit": analyte.unit, "start": iso(start_d), "end": iso(end_d), "points": points}
    if metric not in ("steps", "heart_rate", "sleep", "activity", "blood_pressure", "spo2", "calories"):
        raise errors.unprocessable("Unknown metric.")
    from ..services.wearables import METRIC_UNITS

    return {"metric": metric, "unit": METRIC_UNITS[metric], "start": iso(start_d), "end": iso(end_d), "points": daily_series(db, patient.id, metric, start_d, end_d)}


REPORT_TYPE_LABELS = {
    "full_body": "Full Body Checkup", "blood_report": "Blood", "hba1c": "HbA1c", "blood_glucose": "Blood Glucose", "lipid_profile": "Lipid Profile",
    "kidney_function": "Kidney Function", "liver_function": "Liver Function", "urine_test": "Urine Test", "x_ray": "X-Ray", "mri": "MRI",
    "ct": "CT", "ecg": "ECG", "other": "Other",
}
TIMELINE_FILTERS = ("all", "reports", "assessments", "prescriptions", "visits", "side_effects", "appointments", "ai")
# Filters also accept the names of the event types they show, so a filter always matches its events.
TIMELINE_FILTER_ALIASES = {
    "report": "reports", "assessment": "assessments", "diabetes_risk": "assessments", "prescription": "prescriptions",
    "visit": "visits", "side_effect": "side_effects", "appointment": "appointments", "appointment_recommendation": "appointments",
    "ai_summary": "ai", "ai_summaries": "ai",
}


@router.get("/patients/{patient_id}/timeline")
def timeline(
    patient_id: str,
    type: str = Query("all"),
    limit: int = Query(50, ge=1, le=200),
    before: datetime | None = None,
    current: CurrentUser = Depends(require_record_reader),
    db: Session = Depends(get_db),
):
    """Chronological longitudinal history. Each event keeps its own medical date."""
    patient = authorize_patient(db, current, patient_id)
    type = TIMELINE_FILTER_ALIASES.get(type, type)
    if type not in TIMELINE_FILTERS:
        raise errors.unprocessable("Unknown timeline filter.", {"field": "type"})
    events: list[dict] = []

    def at(d) -> datetime:
        if isinstance(d, datetime):
            return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
        return datetime(d.year, d.month, d.day, tzinfo=timezone.utc)

    if type in ("all", "reports"):
        for r in db.scalars(select(Report).where(Report.patient_id == patient.id)):
            kinds = ", ".join(REPORT_TYPE_LABELS.get(c, c.replace("_", " ").title()) for c in (r.categories or [r.category]))
            events.append({"type": "report", "id": r.id, "date": at(r.report_date), "title": f"{kinds} report", "subtitle": f"Uploaded by {r.uploaded_by_role}", "code": r.report_code})
    if type in ("all", "assessments"):
        for a in db.scalars(select(DiabetesRiskAssessment).where(DiabetesRiskAssessment.patient_id == patient.id)):
            basis = "includes report values" if a.report_available else "without report values"
            events.append({"type": "diabetes_risk", "id": a.id, "date": at(a.created_at), "title": "Future diabetes risk estimate",
                           "subtitle": f"{a.risk_percent:g}% model-estimated risk ({a.risk_category}), {basis}", "code": a.assessment_code})
        for a in db.scalars(select(DiabetesAssessment).where(DiabetesAssessment.patient_id == patient.id)):
            events.append({"type": "assessment", "id": a.id, "date": at(a.assessed_at), "title": "Symptom questionnaire (earlier model)", "subtitle": f"Model classification: {a.prediction}", "code": a.assessment_code})
    if type in ("all", "prescriptions"):
        for p in db.scalars(select(Prescription).where(Prescription.patient_id == patient.id)):
            events.append({"type": "prescription", "id": p.id, "date": at(p.prescribed_on), "title": "Prescription", "subtitle": f"By Dr. {p.doctor_name}", "code": p.prescription_code})
    if type in ("all", "visits"):
        for v in db.scalars(select(Visit).where(Visit.patient_id == patient.id)):
            events.append({"type": "visit", "id": v.id, "date": at(v.visit_date), "title": "Doctor visit", "subtitle": f"Dr. {v.doctor_name}", "code": v.visit_code})
    if type in ("all", "side_effects"):
        for s in db.scalars(select(SideEffect).where(SideEffect.patient_id == patient.id)):
            events.append({"type": "side_effect", "id": s.id, "date": at(s.occurred_at), "title": "Side effect report", "subtitle": s.severity.capitalize(), "code": s.side_effect_code})
    if type in ("all", "appointments"):
        for a in db.scalars(select(AppointmentRecommendation).where(AppointmentRecommendation.patient_id == patient.id)):
            events.append({"type": "appointment_recommendation", "id": a.id, "date": at(a.created_at), "title": "Appointment recommended", "subtitle": f"By Dr. {a.doctor_name}", "code": None})
    if type in ("all", "ai"):
        for s in db.scalars(select(AISummary).where(AISummary.patient_id == patient.id, AISummary.kind.in_(["patient_summary", "all_reports"]))):
            events.append({"type": "ai_summary", "id": s.id, "date": at(s.generated_at), "title": "AI Patient Summary" if s.kind == "patient_summary" else "AI All Reports Summary", "subtitle": "AI-generated", "code": None, "kind": s.kind})
    if before:
        cutoff = at(before)
        events = [e for e in events if e["date"] < cutoff]
    events.sort(key=lambda e: e["date"], reverse=True)
    page = events[:limit]
    for e in page:
        e["date"] = e["date"].isoformat()
    return {"items": page, "has_more": len(events) > limit}

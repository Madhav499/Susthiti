"""AI endpoints. Summaries are stored and reused (no regeneration on every view); regenerating
creates a new version and keeps the old one. Original reports are never replaced."""

import hashlib
import json
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, require_clinical, require_record_reader
from ..models import (
    AISummary,
    AppointmentRecommendation,
    DiabetesAssessment,
    DiabetesRiskAssessment,
    GlucoseReading,
    HeartRiskAssessment,
    Patient,
    Prescription,
    Report,
    SideEffect,
    SideEffectEvent,
    Visit,
)
from ..schemas import AllReportsSummaryIn, age_from, iso, summary_out
from ..services.ai.openrouter import DISCLAIMER, AIResult
from ..services.ai.services import (
    AllReportsSummaryService,
    LifestyleAIService,
    PatientFriendlySummaryService,
    PatientSummaryService,
    ReportSummaryService,
    get_ai_client,
)
from ..services.ai import safety
from ..services.heart_risk.presentation import FEATURE_GROUP as HEART_FEATURE_GROUP
from ..services.health_data import latest_facts
from ..services.health_data.report_values import classify_trend
from ..services.lifestyle_data import food_overview, glucose_overview, lifestyle_snapshot, to_mg_dl
from ..services.pdf import pdf_filename, render_summary_pdf
from ..services.records import audit, notify
from ..services.storage import get_storage

router = APIRouter(tags=["ai"])

MAX_INLINE_BYTES = 15 * 1024 * 1024
MAX_REPORTS_PER_SUMMARY = 25


def _fingerprint(data) -> str:
    return hashlib.sha256(json.dumps(data, sort_keys=True, default=str).encode()).hexdigest()


def _latest(db: Session, patient_id: str, kind: str, subject_id: str | None = None) -> AISummary | None:
    query = select(AISummary).where(AISummary.patient_id == patient_id, AISummary.kind == kind)
    if subject_id:
        query = query.where(AISummary.subject_id == subject_id)
    return db.scalar(query.order_by(AISummary.generated_at.desc()).limit(1))


def _store(db: Session, current: CurrentUser, patient: Patient, kind: str, result: AIResult, source_ids: list[str], fingerprint: str, subject_id: str | None = None, context: dict | None = None) -> AISummary:
    violations = safety.check_output(kind, result.content, context)
    if violations:
        # Never store unsafe output. Log the reason codes only (never the generated
        # content) so this is auditable without leaking unsafe text into logs.
        audit(db, current, "ai_safety_violation", "ai_summary", None, None, {"patient_code": patient.patient_code, "kind": kind, "reasons": violations})
        db.commit()
        raise errors.ApiError(502, "ai_invalid_response", "We couldn't read the AI response. Please try again.")
    content = {**result.content, "disclaimer": DISCLAIMER}
    summary = AISummary(
        patient_id=patient.id, kind=kind, subject_id=subject_id, source_ids=source_ids, source_fingerprint=fingerprint,
        content=content, provider=result.provider, model=result.model, prompt_version=result.prompt_version,
        generated_by_user_id=current.id, generated_by_role=current.role,
    )
    db.add(summary)
    db.flush()
    audit(db, current, f"ai_{kind}_generated", "ai_summary", summary.id, None, {"patient_code": patient.patient_code, "model": result.model})
    return summary


def _reusable(db: Session, patient: Patient, kind: str, fingerprint: str, prompt_version: str, subject_id: str | None = None) -> AISummary | None:
    """The latest summary of this kind, if its source data and prompt version are both
    still current -- regenerating would call the AI for a result that would come out the
    same. Callers skip the AI call entirely and reuse it unless the caller passed force."""
    existing = _latest(db, patient.id, kind, subject_id)
    if existing is not None and existing.source_fingerprint == fingerprint and existing.prompt_version == prompt_version:
        return existing
    return None


def _report_codes(db: Session, ids: list[str]) -> list[str]:
    if not ids:
        return []
    rows = {r.id: r for r in db.scalars(select(Report).where(Report.id.in_(ids)))}
    return [f"{rows[i].report_code} ({rows[i].category.replace('_', ' ')}, {rows[i].report_date:%d %b %Y})" for i in ids if i in rows]


def _report_metadata(r: Report) -> dict:
    return {
        "report_code": r.report_code, "category": r.category, "report_date": iso(r.report_date),
        "uploaded_at": iso(r.uploaded_at), "uploaded_by_role": r.uploaded_by_role, "description": r.description,
    }


# ---------- Individual report summary ----------

@router.get("/reports/{report_id}/summary")
def get_report_summary(report_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    report = db.get(Report, report_id)
    if report is None:
        raise errors.not_found("Report")
    authorize_patient(db, current, report.patient_id)
    summary = _latest(db, report.patient_id, "individual_report", report.id)
    if summary is None:
        return {"summary": None}
    stale = summary.prompt_version != ReportSummaryService.PROMPT_VERSION
    return {"summary": summary_out(summary, stale, based_on=_report_codes(db, summary.source_ids))}


@router.post("/reports/{report_id}/summary", status_code=201)
def generate_report_summary(report_id: str, response: Response, force: bool = Query(False), current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    report = db.get(Report, report_id)
    if report is None:
        raise errors.not_found("Report")
    patient = authorize_patient(db, current, report.patient_id)
    if not force:
        reused = _reusable(db, patient, "individual_report", report.sha256, ReportSummaryService.PROMPT_VERSION, subject_id=report.id)
        if reused is not None:
            response.status_code = 200
            audit(db, current, "ai_individual_report_regeneration_skipped", "ai_summary", reused.id, None, {"patient_code": patient.patient_code})
            db.commit()
            return {"created": False, "summary": summary_out(reused, False, based_on=_report_codes(db, [report.id]))}
    data = get_storage().read(report.storage_ref)
    result = ReportSummaryService(get_ai_client()).summarize(_report_metadata(report), data, report.file_type)
    summary = _store(db, current, patient, "individual_report", result, [report.id], report.sha256, subject_id=report.id)
    notify(db, patient.user_id, "report_summary_ready", "Report summary ready", f"The AI summary for report {report.report_code} is ready.", "report", report.id, patient.id)
    db.commit()
    return {"created": True, "summary": summary_out(summary, based_on=_report_codes(db, [report.id]))}


# ---------- All reports summary ----------

def _all_report_ids(db: Session, patient_id: str) -> list[str]:
    return list(db.scalars(select(Report.id).where(Report.patient_id == patient_id).order_by(Report.report_date, Report.uploaded_at)))


@router.get("/patients/{patient_id}/reports-summary")
def get_all_reports_summary(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    summary = _latest(db, patient.id, "all_reports")
    if summary is None:
        return {"summary": None, "report_count": len(_all_report_ids(db, patient.id))}
    stale = set(_all_report_ids(db, patient.id)) != set(summary.source_ids) or summary.prompt_version != AllReportsSummaryService.PROMPT_VERSION
    return {"summary": summary_out(summary, stale, _report_codes(db, summary.source_ids)), "report_count": len(_all_report_ids(db, patient.id))}


@router.post("/patients/{patient_id}/reports-summary", status_code=201)
def generate_all_reports_summary(patient_id: str, response: Response, body: AllReportsSummaryIn | None = None, force: bool = Query(False), current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    ids = _all_report_ids(db, patient.id)
    if body and body.report_ids:
        wanted = set(body.report_ids)
        if not wanted <= set(ids):
            raise errors.unprocessable("Some selected reports don't belong to this patient.")
        ids = [i for i in ids if i in wanted]
    if len(ids) < 2:
        raise errors.unprocessable("At least two reports are needed to summarize reports over time.")
    ids = ids[-MAX_REPORTS_PER_SUMMARY:]
    if not force:
        reused = _reusable(db, patient, "all_reports", _fingerprint(sorted(ids)), AllReportsSummaryService.PROMPT_VERSION)
        if reused is not None:
            response.status_code = 200
            audit(db, current, "ai_all_reports_regeneration_skipped", "ai_summary", reused.id, None, {"patient_code": patient.patient_code})
            db.commit()
            return {"created": False, "summary": summary_out(reused, False, _report_codes(db, ids))}
    reports = [db.get(Report, i) for i in ids]
    payload, inline_bytes = [], 0
    for r in reports:
        individual = _latest(db, patient.id, "individual_report", r.id)
        item = {"metadata": _report_metadata(r)}
        if individual:
            item["individual_summary"] = {k: v for k, v in individual.content.items() if k != "disclaimer"}
        elif inline_bytes + r.file_size <= MAX_INLINE_BYTES:
            item["file_bytes"] = get_storage().read(r.storage_ref)
            item["mime_type"] = r.file_type
            inline_bytes += r.file_size
        payload.append(item)
    result = AllReportsSummaryService(get_ai_client()).summarize(payload)
    for trend in result.content.get("observed_trends") or []:
        if isinstance(trend, dict):
            earlier = (trend.get("earlier") or {}).get("value")
            latest = (trend.get("latest") or {}).get("value")
            trend.update(classify_trend(str(trend.get("parameter") or ""), earlier, latest))
    summary = _store(db, current, patient, "all_reports", result, ids, _fingerprint(sorted(ids)))
    notify(db, patient.user_id, "report_summary_ready", "Report summary ready", "Your all-reports AI summary is ready.", "ai_summary", summary.id, patient.id)
    db.commit()
    stale = set(_all_report_ids(db, patient.id)) != set(ids)
    return {"created": True, "summary": summary_out(summary, stale, _report_codes(db, ids))}


# ---------- Patient summary ----------

def _patient_record(db: Session, patient: Patient) -> dict:
    """Authorized longitudinal record (real data only; DEMO data and contact details excluded)."""
    assessments = db.scalars(select(DiabetesAssessment).where(DiabetesAssessment.patient_id == patient.id).order_by(DiabetesAssessment.assessed_at))
    risk_assessments = db.scalars(select(DiabetesRiskAssessment).where(DiabetesRiskAssessment.patient_id == patient.id).order_by(DiabetesRiskAssessment.created_at))
    heart_assessments = db.scalars(select(HeartRiskAssessment).where(HeartRiskAssessment.patient_id == patient.id).order_by(HeartRiskAssessment.created_at))
    reports = list(db.scalars(select(Report).where(Report.patient_id == patient.id).order_by(Report.report_date)))
    report_items = []
    for r in reports:
        s = _latest(db, patient.id, "individual_report", r.id)
        report_items.append({**_report_metadata(r), "ai_summary": (s.content.get("summary") if s else None), "key_findings": (s.content.get("key_findings") if s else None)})
    all_reports = _latest(db, patient.id, "all_reports")
    glucose_rows = list(db.scalars(select(GlucoseReading).where(GlucoseReading.patient_id == patient.id, GlucoseReading.is_demo.is_(False)).order_by(GlucoseReading.measured_at)))
    monthly: dict[str, list[float]] = {}
    for g in glucose_rows:
        monthly.setdefault(g.measured_at.strftime("%Y-%m"), []).append(to_mg_dl(g.value, g.unit))
    effects = []
    for s in db.scalars(select(SideEffect).where(SideEffect.patient_id == patient.id).order_by(SideEffect.occurred_at)):
        events = db.scalars(select(SideEffectEvent).where(SideEffectEvent.side_effect_id == s.id, SideEffectEvent.actor_role == "doctor").order_by(SideEffectEvent.created_at))
        effects.append({
            "code": s.side_effect_code, "date": iso(s.occurred_at), "severity": s.severity, "description": s.description,
            "related_medication": s.related_medication, "status": s.status,
            "doctor_responses": [{"by": f"Dr. {e.actor_name}", "date": iso(e.created_at), "response": e.response_type, "message": e.message} for e in events],
        })
    return {
        "patient": {"patient_code": patient.patient_code, "age": age_from(patient.date_of_birth), "gender": patient.gender},
        # Model-estimated FUTURE diabetes risk (a screening estimate, not a diagnosis).
        "future_diabetes_risk_assessments": [
            {"code": a.assessment_code, "date": iso(a.created_at), "model_estimated_risk_percent": a.risk_percent, "risk_category": a.risk_category,
             "basis": "includes medical report values" if a.report_available else "symptoms and risk factors only",
             "report_values_used": list(a.report_fields_present or []), "model_version": a.model_version}
            for a in risk_assessments
        ],
        "earlier_symptom_model_assessments": [
            {"code": a.assessment_code, "date": iso(a.assessed_at), "model_classification": a.prediction, "classification_probability": a.classification_probability, "model_version": a.model_version}
            for a in assessments
        ],
        # Heart disease risk SCREENING (synthetic-data model susthiti-heart-v3; a screening
        # signal, never a diagnosis, never clinically validated, never the same thing as the
        # diabetes risk estimate above).
        "heart_risk_assessments": [
            {"code": a.assessment_code, "date": iso(a.created_at), "screening_score_percent": a.probability_percent, "risk_level": a.risk_level,
             "basis": "includes medical report values" if a.report_available else "symptoms and risk factors only",
             "report_values_used": list(a.report_fields_present or []), "model_version": a.model_version}
            for a in heart_assessments
        ],
        "reports": report_items,
        "all_reports_summary": None if all_reports is None else {k: all_reports.content.get(k) for k in ("summary", "observed_trends")},
        "glucose": {"current": glucose_overview(db, patient.id), "monthly_average_mg_dl": {k: round(sum(v) / len(v), 1) for k, v in monthly.items()}, "total_readings": len(glucose_rows)},
        "lifestyle_recent": lifestyle_snapshot(db, patient.id),
        "food_recent": food_overview(db, patient.id),
        "prescriptions": [
            {"code": p.prescription_code, "date": iso(p.prescribed_on), "doctor": f"Dr. {p.doctor_name}", "medicines": [{"medicine": i.medicine, "dosage": i.dosage, "frequency": i.frequency, "duration": i.duration} for i in p.items], "follow_up": iso(p.follow_up_date)}
            for p in db.scalars(select(Prescription).where(Prescription.patient_id == patient.id).order_by(Prescription.prescribed_on))
        ],
        "side_effects": effects,
        "doctor_visits": [
            {"code": v.visit_code, "date": iso(v.visit_date), "doctor": f"Dr. {v.doctor_name}", "reason": v.reason, "assessment": v.assessment, "treatment_decision": v.treatment_decision, "follow_up": iso(v.follow_up_date)}
            for v in db.scalars(select(Visit).where(Visit.patient_id == patient.id).order_by(Visit.visit_date))
        ],
        "appointment_recommendations": [
            {"date": iso(a.created_at), "doctor": f"Dr. {a.doctor_name}", "reason": a.reason}
            for a in db.scalars(select(AppointmentRecommendation).where(AppointmentRecommendation.patient_id == patient.id).order_by(AppointmentRecommendation.created_at))
        ],
    }


def _has_sufficient_patient_data(record: dict) -> bool:
    """Whether the authorized record has anything worth summarizing. Shared by the doctor's
    patient summary and the patient-friendly summary, which both read the same record."""
    return bool(
        record["reports"]
        or record["future_diabetes_risk_assessments"]
        or record["earlier_symptom_model_assessments"]
        or record["heart_risk_assessments"]
        or record["prescriptions"]
        or record["side_effects"]
        or record["doctor_visits"]
        or record["appointment_recommendations"]
        or record["glucose"]["total_readings"]
        or record["lifestyle_recent"]
        or (record["food_recent"] or {}).get("entries_count")
    )


def _record_version(db: Session, patient_id: str) -> str:
    parts = []
    for model, column in ((Report, Report.uploaded_at), (DiabetesAssessment, DiabetesAssessment.assessed_at),
                          (DiabetesRiskAssessment, DiabetesRiskAssessment.created_at), (HeartRiskAssessment, HeartRiskAssessment.created_at),
                          (Prescription, Prescription.created_at),
                          (Visit, Visit.created_at), (SideEffect, SideEffect.created_at), (GlucoseReading, GlucoseReading.created_at),
                          (SideEffectEvent, None)):
        if column is None:
            parts.append(db.scalar(select(func.count(SideEffectEvent.id)).join(SideEffect).where(SideEffect.patient_id == patient_id)))
            continue
        parts.append(db.scalar(select(func.count()).where(model.patient_id == patient_id)))
        parts.append(str(db.scalar(select(func.max(column)).where(model.patient_id == patient_id))))
    return _fingerprint(parts)


@router.get("/patients/{patient_id}/patient-summary")
def get_patient_summary(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    summary = _latest(db, patient.id, "patient_summary")
    if summary is None:
        return {"summary": None}
    stale = summary.source_fingerprint != _record_version(db, patient.id) or summary.prompt_version != PatientSummaryService.PROMPT_VERSION
    return {"summary": summary_out(summary, stale, ["Full authorized patient record"])}


@router.post("/patients/{patient_id}/patient-summary", status_code=201)
def generate_patient_summary(patient_id: str, response: Response, force: bool = Query(False), current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    record_version = _record_version(db, patient.id)
    if not force:
        reused = _reusable(db, patient, "patient_summary", record_version, PatientSummaryService.PROMPT_VERSION)
        if reused is not None:
            response.status_code = 200
            audit(db, current, "ai_patient_summary_regeneration_skipped", "ai_summary", reused.id, None, {"patient_code": patient.patient_code})
            db.commit()
            return {"created": False, "summary": summary_out(reused, False, ["Full authorized patient record"])}
    record = _patient_record(db, patient)
    if not _has_sufficient_patient_data(record):
        raise errors.unprocessable("No sufficient patient history is available to generate a meaningful summary.")
    result = PatientSummaryService(get_ai_client()).summarize(record)
    summary = _store(db, current, patient, "patient_summary", result, [], record_version)
    db.commit()
    return {"created": True, "summary": summary_out(summary, False, ["Full authorized patient record"])}


# ---------- Patient-friendly summary ----------

@router.get("/patients/{patient_id}/friendly-summary")
def get_patient_friendly_summary(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    summary = _latest(db, patient.id, "patient_friendly_summary")
    if summary is None:
        return {"summary": None}
    stale = summary.source_fingerprint != _record_version(db, patient.id) or summary.prompt_version != PatientFriendlySummaryService.PROMPT_VERSION
    return {"summary": summary_out(summary, stale, ["Full authorized patient record"])}


@router.post("/patients/{patient_id}/friendly-summary", status_code=201)
def generate_patient_friendly_summary(patient_id: str, response: Response, force: bool = Query(False), current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    record_version = _record_version(db, patient.id)
    if not force:
        reused = _reusable(db, patient, "patient_friendly_summary", record_version, PatientFriendlySummaryService.PROMPT_VERSION)
        if reused is not None:
            response.status_code = 200
            audit(db, current, "ai_patient_friendly_summary_regeneration_skipped", "ai_summary", reused.id, None, {"patient_code": patient.patient_code})
            db.commit()
            return {"created": False, "summary": summary_out(reused, False, ["Full authorized patient record"])}
    record = _patient_record(db, patient)
    if not _has_sufficient_patient_data(record):
        raise errors.unprocessable("No sufficient patient history is available to generate a meaningful summary.")
    result = PatientFriendlySummaryService(get_ai_client()).summarize(record)
    summary = _store(db, current, patient, "patient_friendly_summary", result, [], record_version)
    db.commit()
    return {"created": True, "summary": summary_out(summary, False, ["Full authorized patient record"])}


# ---------- Lifestyle insight ----------

def _lifestyle_context(db: Session, patient: Patient) -> dict:
    latest_risk = db.scalar(select(DiabetesRiskAssessment).where(DiabetesRiskAssessment.patient_id == patient.id).order_by(DiabetesRiskAssessment.created_at.desc()).limit(1))
    latest_heart = db.scalar(select(HeartRiskAssessment).where(HeartRiskAssessment.patient_id == patient.id).order_by(HeartRiskAssessment.created_at.desc()).limit(1))
    reports = db.scalars(select(Report).where(Report.patient_id == patient.id, Report.category.in_(["hba1c", "blood_glucose", "lipid_profile", "blood_report"])).order_by(Report.report_date.desc()).limit(5))
    report_context = []
    for r in reports:
        s = _latest(db, patient.id, "individual_report", r.id)
        if s:
            report_context.append({"report_code": r.report_code, "category": r.category, "report_date": iso(r.report_date), "key_findings": s.content.get("key_findings")})
    facts = latest_facts(db, patient.id)
    allergies = (facts["allergies"].value if "allergies" in facts else None) or []
    restrictions = (facts["doctor_restrictions"].value if "doctor_restrictions" in facts else None) or []
    return {
        "recent_lifestyle": lifestyle_snapshot(db, patient.id),
        "glucose": glucose_overview(db, patient.id),
        "food_last_7_days": food_overview(db, patient.id),
        "latest_future_diabetes_risk_estimate": None if latest_risk is None else {
            "date": iso(latest_risk.created_at), "model_estimated_risk_percent": latest_risk.risk_percent, "risk_category": latest_risk.risk_category},
        # Separate synthetic-data screening model (susthiti-heart-v3) -- context only, never a
        # lab value, never equivalent to the diabetes estimate above.
        "latest_heart_risk_screening": None if latest_heart is None else {
            "date": iso(latest_heart.created_at), "screening_score_percent": latest_heart.probability_percent, "risk_level": latest_heart.risk_level},
        "diabetes_report_findings": report_context,
        # Documented and authoritative: suggestions must never conflict with these.
        "allergies": allergies,
        "doctor_restrictions": restrictions,
        "note": "Only real recorded data is included. Missing metrics were not recorded.",
    }


@router.get("/patients/{patient_id}/lifestyle-insight")
def get_lifestyle_insight(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    summary = _latest(db, patient.id, "lifestyle")
    if summary is None:
        return {"summary": None}
    generated = summary.generated_at if summary.generated_at.tzinfo else summary.generated_at.replace(tzinfo=timezone.utc)
    stale = datetime.now(timezone.utc) - generated > timedelta(days=1) or summary.prompt_version != LifestyleAIService.PROMPT_VERSION
    return {"summary": summary_out(summary, stale, ["Lifestyle, food and glucose data (last 7-30 days)"])}


@router.post("/patients/{patient_id}/lifestyle-insight", status_code=201)
def generate_lifestyle_insight(patient_id: str, response: Response, force: bool = Query(False), current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    context = _lifestyle_context(db, patient)
    if not context["recent_lifestyle"] and not context["glucose"]["latest"] and not context["food_last_7_days"]["entries_count"]:
        raise errors.unprocessable("Add some lifestyle, food or glucose data first so there is something to analyze.")
    fingerprint = _fingerprint(context)
    if not force:
        reused = _reusable(db, patient, "lifestyle", fingerprint, LifestyleAIService.PROMPT_VERSION)
        if reused is not None:
            response.status_code = 200
            audit(db, current, "ai_lifestyle_regeneration_skipped", "ai_summary", reused.id, None, {"patient_code": patient.patient_code})
            db.commit()
            return {"created": False, "summary": summary_out(reused, False, ["Lifestyle, food and glucose data (last 7-30 days)"])}
    result = LifestyleAIService(get_ai_client()).suggest(context)
    summary = _store(db, current, patient, "lifestyle", result, [], fingerprint, context=context)
    db.commit()
    return {"created": True, "summary": summary_out(summary, False, ["Lifestyle, food and glucose data (last 7-30 days)"])}


# ---------- Assessment interpretation ----------

@router.post("/assessments/{assessment_id}/interpretation", status_code=201)
def interpret_assessment(assessment_id: str, response: Response, force: bool = Query(False), current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    """AI interpretation that combines the stored model output with lifestyle context.
    It is NOT a new ML prediction, and the assessment record itself is never changed."""
    assessment = db.get(DiabetesAssessment, assessment_id)
    if assessment is None:
        raise errors.not_found("Assessment")
    patient = authorize_patient(db, current, assessment.patient_id)
    model_output = {
        "model_classification": assessment.prediction,
        "classification_probability": assessment.classification_probability,
        "assessed_at": iso(assessment.assessed_at),
        "reported_symptoms": [k for k, v in assessment.inputs.items() if v == "Yes"],
    }
    fingerprint = _fingerprint(model_output)
    if not force:
        reused = _reusable(db, patient, "assessment_interpretation", fingerprint, LifestyleAIService.INTERPRETATION_PROMPT_VERSION, subject_id=assessment.id)
        if reused is not None:
            response.status_code = 200
            audit(db, current, "ai_assessment_interpretation_regeneration_skipped", "ai_summary", reused.id, None, {"patient_code": patient.patient_code})
            db.commit()
            return {"created": False, "summary": summary_out(reused)}
    lifestyle_ctx = _lifestyle_context(db, patient)
    result = LifestyleAIService(get_ai_client()).interpret_assessment(model_output, lifestyle_ctx)
    summary = _store(db, current, patient, "assessment_interpretation", result, [assessment.id], fingerprint, subject_id=assessment.id, context=lifestyle_ctx)
    db.commit()
    return {"created": True, "summary": summary_out(summary)}


@router.post("/heart-risk/{assessment_id}/interpretation", status_code=201)
def interpret_heart_assessment(assessment_id: str, response: Response, force: bool = Query(False), current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    """AI interpretation of a heart disease risk SCREENING result (synthetic-data model
    susthiti-heart-v3) combined with lifestyle context. Mirrors interpret_assessment() above as
    a parallel endpoint -- not a generalization of it -- so diabetes interpretation is untouched.
    It is NOT a new ML prediction, and the assessment record itself is never changed."""
    assessment = db.get(HeartRiskAssessment, assessment_id)
    if assessment is None:
        raise errors.not_found("Assessment")
    patient = authorize_patient(db, current, assessment.patient_id)
    model_output = {
        "screening_result": assessment.prediction_label,
        "screening_score_percent": assessment.probability_percent,
        "risk_level": assessment.risk_level,
        "assessed_at": iso(assessment.created_at),
        "model_version": assessment.model_version,
        "reported_symptoms": [k for k, v in (assessment.input_features or {}).items() if v == 1 and HEART_FEATURE_GROUP.get(k) == "symptoms"],
    }
    fingerprint = _fingerprint(model_output)
    if not force:
        reused = _reusable(db, patient, "heart_interpretation", fingerprint, LifestyleAIService.HEART_INTERPRETATION_PROMPT_VERSION, subject_id=assessment.id)
        if reused is not None:
            response.status_code = 200
            audit(db, current, "ai_heart_interpretation_regeneration_skipped", "ai_summary", reused.id, None, {"patient_code": patient.patient_code})
            db.commit()
            return {"created": False, "summary": summary_out(reused)}
    lifestyle_ctx = _lifestyle_context(db, patient)
    result = LifestyleAIService(get_ai_client()).interpret_heart_assessment(model_output, lifestyle_ctx)
    summary = _store(db, current, patient, "heart_interpretation", result, [assessment.id], fingerprint, subject_id=assessment.id, context=lifestyle_ctx)
    db.commit()
    return {"created": True, "summary": summary_out(summary)}


# ---------- PDF ----------

@router.get("/ai-summaries/{summary_id}/pdf")
def summary_pdf(summary_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    summary = db.get(AISummary, summary_id)
    if summary is None:
        raise errors.not_found("Summary")
    patient = authorize_patient(db, current, summary.patient_id)
    based_on = _report_codes(db, summary.source_ids) if summary.kind in ("individual_report", "all_reports") else ["Authorized patient record"]
    generated = summary.generated_at if summary.generated_at.tzinfo else summary.generated_at.replace(tzinfo=timezone.utc)
    pdf = render_summary_pdf(summary.kind, summary.content, {"name": patient.user.full_name, "code": patient.patient_code}, generated, based_on, summary.model)
    audit(db, current, "ai_summary_pdf_downloaded", "ai_summary", summary.id, None, {"patient_code": patient.patient_code})
    db.commit()
    return Response(pdf, media_type="application/pdf", headers={"Content-Disposition": f'attachment; filename="{pdf_filename(summary.kind, generated)}"', "Cache-Control": "private, no-store"})

"""HeartAssessmentCoordinator: when to assess, and the one place an assessment is created.
Mirrors services/diabetes_risk/coordinator.py's refresh policy.

Two ways to assess:
  * A bare refresh (no form fields) uses only what SUSTHITI already knows (snapshot-derived
    reusable features; every manual-only field -- symptoms, cardiac test results -- is left
    unknown). Nothing is called and nothing is created if nothing reusable changed since the
    last assessment, unless forced.
  * A form submission (manual_fields from the heart assessment questionnaire) always creates a
    new assessment: the patient explicitly answered fresh, point-in-time questions, so the
    result is never deduplicated against an older one.
Either way, each call that reaches the model creates a new immutable record; older ones are
kept -- a heart assessment is never overwritten.
"""

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ...deps import CurrentUser
from ...models import HeartRiskAssessment, Patient
from ..health_data.snapshot import PatientHealthSnapshot, build_snapshot
from ..records import audit, next_code
from . import presentation
from .client import MODEL_VERSION, get_risk_client
from .features import FeatureSet, build_features, changed_features, computed_bmi, merge_manual

_REASONS = (
    ({"hba1c", "fasting_glucose", "random_glucose", "total_cholesterol", "ldl", "hdl", "triglycerides", "troponin", "hemoglobin", "creatinine"},
     "New or changed values from your medical reports"),
    ({"age"}, "Your age has changed"),
    ({"sex", "height_cm", "weight_kg"}, "Your profile or body measurements changed"),
    ({"family_history_heart_disease", "previous_heart_disease", "previous_heart_attack", "hypertension", "high_cholesterol",
      "kidney_disease", "stroke_history"}, "Your medical history changed"),
    ({"resting_heart_rate", "systolic_bp", "diastolic_bp", "oxygen_saturation", "sleep_hours", "physical_activity_level"},
     "Your recent vitals, sleep or activity data changed"),
    ({"sedentary_hours_per_day", "diet_quality", "smoking_status", "alcohol_frequency", "stress_level"}, "Your lifestyle answers changed"),
)


def evaluate(db: Session, patient: Patient, now: datetime | None = None) -> tuple[PatientHealthSnapshot, FeatureSet]:
    snapshot = build_snapshot(db, patient, now)
    return snapshot, build_features(snapshot)


def latest(db: Session, patient_id: str) -> HeartRiskAssessment | None:
    return db.scalar(select(HeartRiskAssessment).where(HeartRiskAssessment.patient_id == patient_id)
                     .order_by(HeartRiskAssessment.created_at.desc()).limit(1))


def stale_reasons(assessment: HeartRiskAssessment, features: FeatureSet) -> list[str]:
    if assessment.model_version != MODEL_VERSION:
        return ["A newer version of the heart risk model is available"]
    if assessment.input_fingerprint == features.fingerprint:
        return []
    changed = set(changed_features(assessment.input_features or {}, features.values))
    reasons = [text for fields, text in _REASONS if changed & fields]
    return reasons or ["Your health information changed"]


def status(db: Session, patient: Patient) -> dict:
    _, features = evaluate(db, patient)
    current = latest(db, patient.id)
    reasons = stale_reasons(current, features) if current else []
    return {
        "latest": presentation.assessment_out(current) if current else None,
        "stale": current is not None and bool(reasons),
        "stale_reasons": reasons,
        # What a bare refresh would use now; the questionnaire form uses the same payload to
        # decide what to prefill (and show as "from your records") before the patient edits it.
        "current_data": presentation.data_used(features.provenance, features.missing),
        "report_fields_available": features.report_fields_present,
        "history_total": db.scalar(select(func.count(HeartRiskAssessment.id)).where(HeartRiskAssessment.patient_id == patient.id)),
    }


def run(db: Session, patient: Patient, current: CurrentUser, manual_fields: dict | None = None, force: bool = False) -> tuple[HeartRiskAssessment, bool]:
    """Returns (assessment, created). manual_fields (from the assessment form) always creates a
    new assessment. Without it, unless forced, creates nothing and calls nothing if the reusable
    inputs are unchanged since the last assessment (the model is deterministic)."""
    snapshot, features = evaluate(db, patient)
    if manual_fields:
        features = merge_manual(features, manual_fields)
    else:
        previous = latest(db, patient.id)
        if not force and previous is not None and not stale_reasons(previous, features):
            return previous, False
    client = get_risk_client()
    client.health()  # never predict against a service that isn't ready
    result = client.predict(features.request_data())
    assessment = HeartRiskAssessment(
        assessment_code=next_code(db, "heart_risk", "HR"), patient_id=patient.id, created_at=datetime.now(timezone.utc),
        performed_by_user_id=current.id, performed_by_role=current.role,
        model_version=result.model_version, probability_percent=result.probability_percent, risk_level=result.risk_level,
        prediction=result.prediction, prediction_label=result.prediction_label, decision_threshold=result.decision_threshold,
        report_available=bool(features.report_fields_present), report_fields_present=features.report_fields_present,
        bmi=computed_bmi(features.values), warnings=result.warnings, input_features=features.request_data(),
        provenance=features.provenance, missing_features=features.missing, input_fingerprint=features.fingerprint,
        snapshot_built_at=snapshot.built_at,
    )
    db.add(assessment)
    db.flush()
    audit(db, current, "heart_risk_assessed", "heart_risk", assessment.id, assessment.assessment_code, {
        "patient_code": patient.patient_code, "model_version": result.model_version,
        "report_available": assessment.report_available, "features_sent": sorted(features.request_data()),
    })
    db.commit()
    return assessment, True

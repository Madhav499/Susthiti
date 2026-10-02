"""DiabetesAssessmentCoordinator: when to assess, and the one place an assessment is created.

Refresh policy
  * Nothing calls the model on its own. Opening a screen only *reads* the latest stored
    assessment and compares its inputs with the patient's current data.
  * If an input changed at a precision that matters (features.fingerprint) — a new report value,
    a health profile answer, sleep/activity averages, age, a new model version — the assessment
    is marked out of date, with the reasons, and the patient (or their doctor) can refresh it.
  * Refreshing with unchanged inputs does not call the model again and creates no new record
    (the model is deterministic, so the result would be identical).
  * Each refresh that does call the model creates a new immutable record; older ones are kept.
"""

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ...deps import CurrentUser
from ...models import DiabetesAssessment, DiabetesRiskAssessment, Patient
from ..health_data.snapshot import PatientHealthSnapshot, build_snapshot
from ..records import audit, next_code
from . import presentation
from .client import get_risk_client, version_major
from .features import SUPPORTED_MAJOR, FeatureSet, build_features, changed_features

_REASONS = (
    ({"hba1c", "fasting_glucose", "random_glucose", "previous_ogtt_2h", "previous_health_report_status"}, "New or changed values from your medical reports"),
    ({"age"}, "Your age has changed"),
    ({"sex", "height_cm", "weight_kg"}, "Your profile or body measurements changed"),
    ({"family_history_diabetes", "previous_prediabetes", "previous_gestational_diabetes", "hypertension", "high_cholesterol", "pcos",
      "cardiovascular_disease", "fatty_liver_disease"}, "Your medical history changed"),
    ({"sleep_hours", "physical_activity_level"}, "Your recent sleep or activity data changed"),
    ({"sedentary_hours_per_day", "diet_quality", "sugary_drink_frequency", "smoking_status", "alcohol_frequency", "stress_level"}, "Your lifestyle answers changed"),
    ({"polyuria", "polydipsia", "unexplained_weight_loss", "polyphagia"}, "Your symptom answers changed"),
)


def evaluate(db: Session, patient: Patient, now: datetime | None = None) -> tuple[PatientHealthSnapshot, FeatureSet]:
    snapshot = build_snapshot(db, patient, now)
    return snapshot, build_features(snapshot)


def latest(db: Session, patient_id: str) -> DiabetesRiskAssessment | None:
    return db.scalar(select(DiabetesRiskAssessment).where(DiabetesRiskAssessment.patient_id == patient_id)
                     .order_by(DiabetesRiskAssessment.created_at.desc()).limit(1))


def stale_reasons(assessment: DiabetesRiskAssessment, features: FeatureSet) -> list[str]:
    if version_major(assessment.model_version) != SUPPORTED_MAJOR:
        return ["A newer version of the risk model is available"]
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
        # What a refresh would use now (for "Data used" before the first assessment and after changes).
        "current_data": presentation.data_used(features.provenance, features.missing),
        "report_fields_available": features.report_fields_present,
        "history_total": db.scalar(select(func.count(DiabetesRiskAssessment.id)).where(DiabetesRiskAssessment.patient_id == patient.id)),
        "earlier_model_total": db.scalar(select(func.count(DiabetesAssessment.id)).where(DiabetesAssessment.patient_id == patient.id)),
    }


def run(db: Session, patient: Patient, current: CurrentUser, force: bool = False) -> tuple[DiabetesRiskAssessment, bool]:
    """Returns (assessment, created). Unless forced, creates nothing and calls nothing if the inputs
    are unchanged. force: the patient re-answered every question and asked for a new assessment."""
    snapshot, features = evaluate(db, patient)
    previous = latest(db, patient.id)
    if not force and previous is not None and not stale_reasons(previous, features):
        return previous, False
    client = get_risk_client()
    client.health()  # never predict against a service that isn't ready
    result = client.predict(features.request_data())
    assessment = DiabetesRiskAssessment(
        assessment_code=next_code(db, "diabetes_risk", "DR"), patient_id=patient.id, created_at=datetime.now(timezone.utc),
        performed_by_user_id=current.id, performed_by_role=current.role,
        model_version=result.model_version, risk_percent=result.risk_percent, risk_category=result.risk_category,
        risk_thresholds=result.risk_thresholds, prediction=result.prediction, prediction_label=result.prediction_label,
        prediction_threshold=result.prediction_threshold, prediction_basis=result.prediction_basis,
        report_available=result.report_available, report_fields_present=result.report_fields_present, bmi=result.bmi,
        warning=result.warning, input_features=features.request_data(), provenance=features.provenance,
        missing_features=features.missing, input_fingerprint=features.fingerprint, snapshot_built_at=snapshot.built_at,
    )
    db.add(assessment)
    db.flush()
    audit(db, current, "diabetes_risk_assessed", "diabetes_risk", assessment.id, assessment.assessment_code, {
        "patient_code": patient.patient_code, "model_version": result.model_version,
        "report_available": result.report_available, "features_sent": sorted(features.request_data()),
    })
    db.commit()
    return assessment, True

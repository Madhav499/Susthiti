"""PatientHealthSnapshot: the patient's current known state, built on request from stored records.

Concept names (keys of `observations`):
  age, sex                                   patient profile (age from date of birth, today)
  <health profile field key>                 health profile answers (profile_fields.FIELDS)
  lab.<analyte>                              values confirmed from uploaded reports
  measured.sleep_hours                       average nightly sleep, health platform / manual logs
  measured.daily_steps                       average daily steps, health platform / manual logs
  questionnaire.<symptom>                    answers from the earlier symptom questionnaire

Freshness (documented in docs/diabetes-api-v4-integration.md):
  * health profile answers expire after their field's fresh_days (None: never);
  * report values: newest report wins; reports older than 2 years are not current;
  * sleep: last 14 days, at least 3 nights recorded; steps: last 14 days, at least 7 days;
  * questionnaire symptoms: only if answered within the last 90 days.
Demo data (is_demo) is never used as health data.
"""

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from statistics import mean
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import DiabetesAssessment, HealthFact, Patient
from ..lifestyle_data import daily_series
from . import report_values as rv
from .profile_fields import BY_KEY as PROFILE_FIELDS

PATIENT_PROFILE = "patient_profile"
HEALTH_PROFILE = "health_profile"
MEDICAL_REPORT = "medical_report"
WEARABLE = "wearable"  # a connected health platform / device
LIFESTYLE_LOG = "lifestyle_log"  # entered manually in SUSTHITI
QUESTIONNAIRE = "symptom_questionnaire"

LIFESTYLE_WINDOW_DAYS = 14
MIN_SLEEP_NIGHTS = 3
MIN_STEP_DAYS = 7
QUESTIONNAIRE_FRESH_DAYS = 90

# Old questionnaire (retired 16-feature model) answers that mean the same symptom.
_QUESTIONNAIRE_SYMPTOMS = {"polyuria": "Polyuria", "polydipsia": "Polydipsia", "unexplained_weight_loss": "sudden weight loss", "polyphagia": "Polyphagia"}


def aware(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


@dataclass(frozen=True)
class Observation:
    value: Any
    source: str
    recorded_at: datetime | date | None
    source_id: str | None = None
    detail: str = ""
    meta: dict = field(default_factory=dict)

    def as_dict(self) -> dict:
        at = self.recorded_at
        return {
            "value": self.value, "source": self.source, "source_id": self.source_id, "detail": self.detail,
            "recorded_at": at.isoformat() if at else None, **({"meta": self.meta} if self.meta else {}),
        }


@dataclass
class PatientHealthSnapshot:
    patient_id: str
    built_at: datetime
    observations: dict[str, Observation] = field(default_factory=dict)
    # Why a concept has no usable value (not recorded, answered "not sure", too old...).
    unknown: dict[str, str] = field(default_factory=dict)
    # Earlier values kept for context (e.g. the previous HbA1c), never used as current.
    history: dict[str, Observation] = field(default_factory=dict)

    def get(self, concept: str) -> Observation | None:
        return self.observations.get(concept)


def build_snapshot(db: Session, patient: Patient, now: datetime | None = None) -> PatientHealthSnapshot:
    now = aware(now) or datetime.now(timezone.utc)
    today = now.date()
    snap = PatientHealthSnapshot(patient_id=patient.id, built_at=now)
    _profile(snap, patient, today)
    _health_profile(db, snap, patient, now)
    _reports(db, snap, patient, today)
    _lifestyle(db, snap, patient, today)
    _questionnaire(db, snap, patient, now)
    return snap


def _profile(snap: PatientHealthSnapshot, patient: Patient, today: date) -> None:
    if patient.date_of_birth:
        dob = patient.date_of_birth
        age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
        snap.observations["age"] = Observation(age, PATIENT_PROFILE, dob, patient.id, "Calculated today from your date of birth")
    else:
        snap.unknown["age"] = "Date of birth is not in the profile"
    if patient.gender in ("Male", "Female"):
        snap.observations["sex"] = Observation(patient.gender, PATIENT_PROFILE, None, patient.id, "From your profile")
    else:
        snap.unknown["sex"] = "Not in the profile"


def _health_profile(db: Session, snap: PatientHealthSnapshot, patient: Patient, now: datetime) -> None:
    latest: dict[str, HealthFact] = {}
    for fact in db.scalars(select(HealthFact).where(HealthFact.patient_id == patient.id).order_by(HealthFact.recorded_at)):
        latest[fact.field] = fact  # later rows win
    for key, spec in PROFILE_FIELDS.items():
        fact = latest.get(key)
        if fact is None:
            snap.unknown[key] = "Not answered yet"
            continue
        recorded = aware(fact.recorded_at)
        if spec.fresh_days is not None and (now - recorded).days > spec.fresh_days:
            snap.unknown[key] = f"Last answered {recorded:%d %b %Y}; answers older than {spec.fresh_days} days are not used"
            continue
        if fact.value is None:
            snap.unknown[key] = "Answered \"not sure\""
            continue
        by = "your doctor" if fact.recorded_by_role == "doctor" else "you"
        snap.observations[key] = Observation(fact.value, HEALTH_PROFILE, recorded, fact.id, f"Health profile, entered by {by} on {recorded:%d %b %Y}",
                                             {"recorded_by_role": fact.recorded_by_role, "group": spec.group})


def _reports(db: Session, snap: PatientHealthSnapshot, patient: Patient, today: date) -> None:
    current = rv.current_values(db, patient.id, today)
    for key, analyte in rv.ANALYTES.items():
        concept = f"lab.{key}"
        item = current.get(key)
        if item is None:
            snap.unknown[concept] = "Not recorded from any uploaded report"
            continue
        obs = _report_observation(item.current, item.report, analyte)
        if item.too_old:
            snap.unknown[concept] = f"Latest value is from {item.current.measured_on:%d %b %Y}; reports older than 2 years are not used"
            snap.history[concept] = obs
            continue
        snap.observations[concept] = obs
        if item.previous is not None and item.previous_report is not None:
            snap.history[concept] = _report_observation(item.previous, item.previous_report, analyte)


def _report_observation(value, report, analyte: rv.Analyte) -> Observation:
    shown = value.text_value if analyte.kind == "classification" else value.value
    by = "your doctor" if value.confirmed_by_role == "doctor" else "you"
    if value.origin in ("auto_extracted", "ai_extracted"):
        reader = "read automatically from the report" if value.origin == "auto_extracted" else "read automatically by the AI reader"
        how_by = f"{reader}, not yet checked" if value.confirmed_by_role == "automatic" else f"{reader} and checked by {by}"
    else:
        how = "suggested by the AI report summary and confirmed" if value.origin == "ai_suggestion" else "entered"
        how_by = f"{how} by {by}"
    return Observation(
        shown, MEDICAL_REPORT, value.measured_on, report.id,
        f"{analyte.label} from report {report.report_code} ({value.measured_on:%d %b %Y}), {how_by}",
        {"report_code": report.report_code, "report_category": report.category, "unit": value.unit, "origin": value.origin,
         "confirmed_by_role": value.confirmed_by_role, "report_value_id": value.id},
    )


def _lifestyle(db: Session, snap: PatientHealthSnapshot, patient: Patient, today: date) -> None:
    start = today - timedelta(days=LIFESTYLE_WINDOW_DAYS - 1)
    window = f"{start:%d %b} – {today:%d %b %Y}"

    def source_of(points: list[dict]) -> str:
        sources = {s for p in points for s in p.get("sources", [])}
        return WEARABLE if sources & {"health_platform", "device", "imported"} else LIFESTYLE_LOG

    sleep = [p for p in daily_series(db, patient.id, "sleep", start, today, include_demo=False) if p["value"] and p["value"] > 0]
    if len(sleep) >= MIN_SLEEP_NIGHTS:
        hours = round(mean(p["value"] for p in sleep) / 60, 1)
        snap.observations["measured.sleep_hours"] = Observation(
            hours, source_of(sleep), date.fromisoformat(sleep[-1]["date"]), None,
            f"Average of {len(sleep)} nights recorded {window}", {"nights": len(sleep), "window_days": LIFESTYLE_WINDOW_DAYS},
        )
    else:
        snap.unknown["measured.sleep_hours"] = f"Sleep recorded on {len(sleep)} of the last {LIFESTYLE_WINDOW_DAYS} nights (needs {MIN_SLEEP_NIGHTS})"

    steps = [p for p in daily_series(db, patient.id, "steps", start, today, include_demo=False) if p["value"] is not None]
    if len(steps) >= MIN_STEP_DAYS:
        average = round(mean(p["value"] for p in steps))
        snap.observations["measured.daily_steps"] = Observation(
            average, source_of(steps), date.fromisoformat(steps[-1]["date"]), None,
            f"Average of {len(steps)} days recorded {window}", {"days": len(steps), "window_days": LIFESTYLE_WINDOW_DAYS},
        )
    else:
        snap.unknown["measured.daily_steps"] = f"Steps recorded on {len(steps)} of the last {LIFESTYLE_WINDOW_DAYS} days (needs {MIN_STEP_DAYS})"


def _questionnaire(db: Session, snap: PatientHealthSnapshot, patient: Patient, now: datetime) -> None:
    latest = db.scalar(select(DiabetesAssessment).where(DiabetesAssessment.patient_id == patient.id).order_by(DiabetesAssessment.assessed_at.desc()).limit(1))
    if latest is None:
        return
    answered = aware(latest.assessed_at)
    if (now - answered).days > QUESTIONNAIRE_FRESH_DAYS:
        return
    for concept, old_name in _QUESTIONNAIRE_SYMPTOMS.items():
        answer = (latest.inputs or {}).get(old_name)
        if answer in ("Yes", "No"):
            snap.observations[f"questionnaire.{concept}"] = Observation(
                answer == "Yes", QUESTIONNAIRE, answered, latest.id, f"Symptom questionnaire answered on {answered:%d %b %Y}",
            )

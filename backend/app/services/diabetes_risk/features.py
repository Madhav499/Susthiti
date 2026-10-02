"""DiabetesFeatureBuilder: PatientHealthSnapshot -> the 30 input fields of API v4.

This is the only place that decides how SUSTHITI's health data maps to the model. Rules:
  * a feature is sent only when its value is genuinely known; unknown stays null (omitted),
    never 0, "No", "Normal" or an average;
  * each feature has a fixed source order (FEATURE_SOURCES): the first source with a usable
    value wins, and where it came from is recorded (provenance);
  * report fields come only from values confirmed on uploaded reports; previous_prediabetes is
    medical history and is never report evidence;
  * previous_health_report_status is sent only as Normal / Prediabetes / Diabetes read off a
    report, never as "Available" and never inferred from lab values;
  * BMI is left to the API, which computes it from height and weight (one BMI, one place);
  * wearable data is used only where it maps to a model field: sleep -> sleep_hours, daily
    steps -> physical_activity_level. Heart rate, SpO2, blood pressure and calories have no
    model field and are never converted into one.
"""

import hashlib
import json
from dataclasses import dataclass, field
from typing import Any

from ..health_data.snapshot import PatientHealthSnapshot

MODEL_FAMILY = "susthiti-future-diabetes-risk"
SUPPORTED_MAJOR = 4

# API v4 FEATURES, in the API's order.
FEATURES: tuple[str, ...] = (
    "age", "sex", "height_cm", "weight_kg", "bmi",
    "family_history_diabetes", "previous_prediabetes", "previous_gestational_diabetes", "physical_activity_level",
    "sedentary_hours_per_day", "diet_quality", "sugary_drink_frequency", "smoking_status", "alcohol_frequency",
    "hypertension", "high_cholesterol", "pcos", "cardiovascular_disease", "fatty_liver_disease", "sleep_hours",
    "stress_level", "polyuria", "polydipsia", "unexplained_weight_loss", "polyphagia",
    "hba1c", "fasting_glucose", "random_glucose", "previous_ogtt_2h", "previous_health_report_status",
)
# API v4 REPORT_FIELDS: only these make report_available true.
REPORT_FIELDS: tuple[str, ...] = ("hba1c", "fasting_glucose", "random_glucose", "previous_ogtt_2h", "previous_health_report_status")

BINARY = {
    "family_history_diabetes", "previous_prediabetes", "previous_gestational_diabetes", "hypertension", "high_cholesterol",
    "pcos", "cardiovascular_disease", "fatty_liver_disease", "polyuria", "polydipsia", "unexplained_weight_loss", "polyphagia",
}

# SUSTHITI vocabulary -> API v4 vocabulary (API main.py CATEGORICAL_VALUES).
VOCABULARY: dict[str, dict[str, str]] = {
    "sex": {"Male": "Male", "Female": "Female"},
    "physical_activity_level": {"low": "Low", "moderate": "Moderate", "high": "High"},
    "diet_quality": {"good": "Good", "average": "Average", "poor": "Poor"},
    "sugary_drink_frequency": {"never_rarely": "Never/Rarely", "1_3_per_week": "1-3_per_week", "4_6_per_week": "4-6_per_week", "daily": "Daily"},
    "smoking_status": {"never": "Never", "former": "Former", "current": "Current"},
    "alcohol_frequency": {"never": "Never", "occasionally": "Occasionally", "weekly": "Weekly", "frequent": "Frequent"},
    "stress_level": {"low": "Low", "moderate": "Moderate", "high": "High"},
    "previous_health_report_status": {"normal": "Normal", "prediabetes": "Prediabetes", "diabetes": "Diabetes"},
}

# Daily steps -> activity level (Tudor-Locke & Bassett 2004 step bands: <5,000 sedentary;
# 5,000-9,999 low to somewhat active; >=10,000 active).
STEP_BANDS = ((5000, "low"), (10000, "moderate"))


def activity_from_steps(average_steps: float) -> str:
    for upper, level in STEP_BANDS:
        if average_steps < upper:
            return level
    return "high"


# Source order per feature: snapshot concepts, first usable one wins.
FEATURE_SOURCES: dict[str, tuple[str, ...]] = {
    "age": ("age",),
    "sex": ("sex",),
    "height_cm": ("height_cm",),
    "weight_kg": ("weight_kg",),
    "bmi": (),  # computed by the API from height_cm and weight_kg
    "family_history_diabetes": ("family_history_diabetes",),
    "previous_prediabetes": ("previous_prediabetes",),
    "previous_gestational_diabetes": ("previous_gestational_diabetes",),
    "physical_activity_level": ("measured.daily_steps", "physical_activity_level"),
    "sedentary_hours_per_day": ("sedentary_hours_per_day",),
    "diet_quality": ("diet_quality",),
    "sugary_drink_frequency": ("sugary_drink_frequency",),
    "smoking_status": ("smoking_status",),
    "alcohol_frequency": ("alcohol_frequency",),
    "hypertension": ("hypertension",),
    "high_cholesterol": ("high_cholesterol",),
    "pcos": ("pcos",),
    "cardiovascular_disease": ("cardiovascular_disease",),
    "fatty_liver_disease": ("fatty_liver_disease",),
    "sleep_hours": ("measured.sleep_hours",),
    "stress_level": ("stress_level",),
    "polyuria": ("polyuria", "questionnaire.polyuria"),
    "polydipsia": ("polydipsia", "questionnaire.polydipsia"),
    "unexplained_weight_loss": ("unexplained_weight_loss", "questionnaire.unexplained_weight_loss"),
    "polyphagia": ("polyphagia", "questionnaire.polyphagia"),
    "hba1c": ("lab.hba1c",),
    "fasting_glucose": ("lab.fasting_glucose",),
    "random_glucose": ("lab.random_glucose",),
    "previous_ogtt_2h": ("lab.ogtt_2h",),
    "previous_health_report_status": ("lab.diabetes_classification",),
}

# How precisely a value must change before the assessment counts as out of date (fingerprint).
_BUCKETS = {"height_cm": 1.0, "weight_kg": 1.0, "sedentary_hours_per_day": 0.5, "sleep_hours": 0.5}


@dataclass
class FeatureSet:
    values: dict[str, Any]
    provenance: list[dict] = field(default_factory=list)
    missing: list[dict] = field(default_factory=list)

    def request_data(self) -> dict[str, Any]:
        """Exactly what is sent to /predict: known model features only (unknown ones omitted)."""
        return {k: v for k, v in self.values.items() if v is not None}

    @property
    def report_fields_present(self) -> list[str]:
        return [f for f in REPORT_FIELDS if self.values.get(f) is not None]

    @property
    def fingerprint(self) -> str:
        return fingerprint(self.values)


def fingerprint(values: dict[str, Any]) -> str:
    """Hash of the model inputs at the precision that matters, plus the model family/version."""
    bucketed = {"_model": f"{MODEL_FAMILY}/v{SUPPORTED_MAJOR}"}
    for key in FEATURES:
        value = values.get(key)
        step = _BUCKETS.get(key)
        if value is not None and step is not None:
            value = round(round(float(value) / step) * step, 2)
        bucketed[key] = value
    return hashlib.sha256(json.dumps(bucketed, sort_keys=True).encode()).hexdigest()


def changed_features(old: dict[str, Any], new: dict[str, Any]) -> list[str]:
    return [k for k in FEATURES if fingerprint({k: old.get(k)}) != fingerprint({k: new.get(k)})]


def build_features(snapshot: PatientHealthSnapshot) -> FeatureSet:
    values: dict[str, Any] = {k: None for k in FEATURES}
    provenance: list[dict] = []
    missing: list[dict] = []
    for feature in FEATURES:
        sources = FEATURE_SOURCES[feature]
        if not sources:
            continue
        for concept in sources:
            obs = snapshot.get(concept)
            if obs is None:
                continue
            value = _to_model(feature, concept, obs.value)
            if value is None:
                continue
            values[feature] = value
            recorded = obs.as_dict()["recorded_at"]
            detail = obs.detail
            if concept == "measured.daily_steps":
                detail = f"{obs.detail}: about {obs.value:,} steps a day, so {value.lower()} activity"
            provenance.append({
                "feature": feature, "value": value, "source_value": obs.value, "concept": concept, "source": obs.source,
                "source_id": obs.source_id, "recorded_at": recorded, "detail": detail, "meta": obs.meta,
            })
            break
        else:
            reasons = [snapshot.unknown[c] for c in sources if c in snapshot.unknown]
            missing.append({"feature": feature, "reason": reasons[0] if reasons else "Not recorded"})
    return FeatureSet(values=values, provenance=provenance, missing=missing)


def _to_model(feature: str, concept: str, value: Any) -> Any:
    if value is None:
        return None
    if concept == "measured.daily_steps":
        return VOCABULARY["physical_activity_level"][activity_from_steps(float(value))]
    if feature in BINARY:
        if not isinstance(value, bool):
            return None
        return 1 if value else 0
    if feature in VOCABULARY:
        return VOCABULARY[feature].get(value)  # anything outside the vocabulary is not sent
    if feature == "age":
        return int(value)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return float(value)

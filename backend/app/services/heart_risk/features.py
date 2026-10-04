"""HeartFeatureBuilder: PatientHealthSnapshot (+ the manual assessment form) -> the 59 input
fields of the supplied Heart Risk API (model susthiti-heart-v3). Rules, mirroring
services/diabetes_risk/features.py:

  * a feature is sent only when its value is genuinely known; unknown stays null (omitted),
    never 0, "No", "Normal" or "Never" -- see _MANUAL_ONLY below for fields that have no
    durable SUSTHITI concept and must always come from the manual form (or stay unknown);
  * reusable features have a fixed source order (FEATURE_SOURCES): the first snapshot concept
    with a usable value wins, and where it came from is recorded (provenance);
  * `diabetes` (the heart model's own yes/no field) is never inferred from the diabetes risk
    screening score -- it has no safe existing source and is always manual/unknown;
  * BMI is left to the API, which computes it from height and weight;
  * symptom, pain and cardiac-test-result fields are point-in-time for this one assessment:
    they are never written back into the durable health profile and never prefilled from an
    earlier heart assessment, even though the lab values (troponin, lipids, hemoglobin,
    creatinine) and vitals (heart rate, SpO2, blood pressure) are reusable when SUSTHITI
    already has a confirmed recent value.
"""

import hashlib
import json
from dataclasses import dataclass, field
from typing import Any

from ..health_data.snapshot import PatientHealthSnapshot

MODEL_VERSION = "susthiti-heart-v3"

# API FEATURES, as returned by the supplied model bundle's /model-info (59 fields). Kept here
# for the source-mapping below; the client cross-checks this list against the live service on
# every health() call so a mismatch is caught at runtime, not assumed from this transcription.
FEATURES: tuple[str, ...] = (
    "age", "sex", "height_cm", "weight_kg", "bmi",
    "smoking_status", "alcohol_frequency", "physical_activity_level",
    "family_history_heart_disease", "previous_heart_disease", "previous_heart_attack",
    "hypertension", "diabetes", "high_cholesterol", "kidney_disease", "stroke_history",
    "chest_pain", "chest_pain_type", "chest_pain_duration_min", "shortness_of_breath", "fatigue",
    "dizziness", "fainting", "sweating", "nausea", "palpitations", "pain_left_arm", "pain_jaw_neck", "pain_back",
    "resting_heart_rate", "systolic_bp", "diastolic_bp", "oxygen_saturation", "respiratory_rate",
    "fasting_glucose", "random_glucose", "hba1c", "total_cholesterol", "ldl", "hdl", "triglycerides",
    "troponin", "hemoglobin", "creatinine",
    "resting_ecg", "ecg_abnormality", "st_depression", "exercise_induced_angina", "max_heart_rate",
    "exercise_duration_min", "stress_test_result", "echocardiogram_result", "ejection_fraction",
    "heart_wall_motion_abnormality", "previous_cardiac_test_abnormal",
    "sleep_hours", "stress_level", "sedentary_hours_per_day", "diet_quality",
)

# Only these make report_available true -- the lab values a report can actually confirm.
REPORT_FIELDS: tuple[str, ...] = (
    "fasting_glucose", "random_glucose", "hba1c",
    "total_cholesterol", "ldl", "hdl", "triglycerides", "troponin", "hemoglobin", "creatinine",
)

BINARY = {
    "family_history_heart_disease", "previous_heart_disease", "previous_heart_attack", "hypertension", "diabetes",
    "high_cholesterol", "kidney_disease", "stroke_history", "chest_pain", "shortness_of_breath", "fatigue",
    "dizziness", "fainting", "sweating", "nausea", "palpitations", "pain_left_arm", "pain_jaw_neck", "pain_back",
    "ecg_abnormality", "exercise_induced_angina", "heart_wall_motion_abnormality", "previous_cardiac_test_abnormal",
}

# Fields with no durable SUSTHITI concept: always come from the manual assessment form (or stay
# unknown). Never derived from the snapshot, never defaulted.
MANUAL_ONLY = {
    "diabetes",  # the heart model's own field; never inferred from the diabetes risk screening
    "chest_pain", "chest_pain_type", "chest_pain_duration_min", "shortness_of_breath", "fatigue", "dizziness",
    "fainting", "sweating", "nausea", "palpitations", "pain_left_arm", "pain_jaw_neck", "pain_back",
    "respiratory_rate",
    "resting_ecg", "ecg_abnormality", "st_depression", "exercise_induced_angina", "max_heart_rate",
    "exercise_duration_min", "stress_test_result", "echocardiogram_result", "ejection_fraction",
    "heart_wall_motion_abnormality", "previous_cardiac_test_abnormal",
    # The heart model's stress_level is numeric (0-10); SUSTHITI's existing stress_level profile
    # field (shared with diabetes) is a Low/Moderate/High choice -- a different scale, so it is
    # never reused here rather than guessing a number from a category.
    "stress_level",
}

# SUSTHITI vocabulary -> heart API vocabulary (API main.py's own category strings / ALIASES).
VOCABULARY: dict[str, dict[str, Any]] = {
    "sex": {"male": "Male", "female": "Female"},
    "smoking_status": {"never": "Never", "former": "Former", "current": "Current"},
    # SUSTHITI's "weekly" has no exact heart-API equivalent (Never/Rare/Occasional/Frequent);
    # mapped to the more conservative "Occasional" rather than overstating it as "Frequent".
    "alcohol_frequency": {"never": "Never", "occasionally": "Occasional", "weekly": "Occasional", "frequent": "Frequent"},
    "physical_activity_level": {"low": "Low", "moderate": "Moderate", "high": "High"},
    "diet_quality": {"good": "Good", "average": "Average", "poor": "Poor"},
    # Manual-only categorical fields: SUSTHITI's own simple keys (used by the Flutter form),
    # mapped to the heart API's category strings.
    "chest_pain_type": {"none": None, "typical_angina": "Typical_Angina", "atypical_angina": "Atypical_Angina", "non_anginal": "Non_Anginal"},
    "resting_ecg": {"normal": "Normal", "normal_variant": "Normal_Variant", "st_t_abnormality": "ST_T_Abnormality",
                     "old_infarct_pattern": "Old_Infarct_Pattern", "lvh": "LVH"},
    "stress_test_result": {"negative": "Negative", "borderline": "Borderline", "positive": "Positive"},
    "echocardiogram_result": {"normal": "Normal", "mild_abnormality": "Mild_Abnormality", "significant_abnormality": "Significant_Abnormality"},
}

# Daily steps -> activity level, same step bands as the diabetes feature builder (duplicated,
# not imported, so the two sibling services stay independent).
_STEP_BANDS = ((5000, "low"), (10000, "moderate"))


def _activity_from_steps(average_steps: float) -> str:
    for upper, level in _STEP_BANDS:
        if average_steps < upper:
            return level
    return "high"


# Source order per reusable feature: snapshot concepts, first usable one wins. Fields in
# MANUAL_ONLY are intentionally absent here (and must stay out of it).
FEATURE_SOURCES: dict[str, tuple[str, ...]] = {
    "age": ("age",),
    "sex": ("sex",),
    "height_cm": ("height_cm",),
    "weight_kg": ("weight_kg",),
    "bmi": (),  # computed by the API from height_cm and weight_kg
    "smoking_status": ("smoking_status",),
    "alcohol_frequency": ("alcohol_frequency",),
    "physical_activity_level": ("measured.daily_steps", "physical_activity_level"),
    "family_history_heart_disease": ("family_history_heart_disease",),
    "previous_heart_disease": ("previous_heart_disease",),
    "previous_heart_attack": ("previous_heart_attack",),
    "hypertension": ("hypertension",),
    "high_cholesterol": ("high_cholesterol",),
    "kidney_disease": ("kidney_disease",),
    "stroke_history": ("stroke_history",),
    "resting_heart_rate": ("measured.resting_heart_rate",),
    "systolic_bp": ("measured.systolic_bp",),
    "diastolic_bp": ("measured.diastolic_bp",),
    "oxygen_saturation": ("measured.oxygen_saturation",),
    "fasting_glucose": ("lab.fasting_glucose",),
    "random_glucose": ("lab.random_glucose",),
    "hba1c": ("lab.hba1c",),
    "total_cholesterol": ("lab.total_cholesterol",),
    "ldl": ("lab.ldl",),
    "hdl": ("lab.hdl",),
    "triglycerides": ("lab.triglycerides",),
    "troponin": ("lab.troponin",),
    "hemoglobin": ("lab.hemoglobin",),
    "creatinine": ("lab.creatinine",),
    "sleep_hours": ("measured.sleep_hours",),
    "sedentary_hours_per_day": ("sedentary_hours_per_day",),
    "diet_quality": ("diet_quality",),
}

# Every feature is either reusable (a FEATURE_SOURCES key, including "bmi" with no source) or
# manual-only, and never both -- checked at import time so a typo here fails loudly, not silently.
assert set(FEATURE_SOURCES) | MANUAL_ONLY == set(FEATURES), "FEATURE_SOURCES + MANUAL_ONLY must cover exactly the 59 model features"
assert not (set(FEATURE_SOURCES) & MANUAL_ONLY), "a feature cannot be both reusable and manual-only"

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
    """Hash of the model inputs at the precision that matters, plus the model version."""
    bucketed: dict[str, Any] = {"_model": MODEL_VERSION}
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
    """Reusable features only (from the snapshot). Manual-only fields are always reported
    missing here; the questionnaire form is the only place they can be filled in -- see
    merge_manual()."""
    values: dict[str, Any] = {k: None for k in FEATURES}
    provenance: list[dict] = []
    missing: list[dict] = []
    for feature in FEATURES:
        sources = FEATURE_SOURCES.get(feature, ())
        if not sources:
            if feature != "bmi":
                missing.append({"feature": feature, "reason": "Answered on the heart assessment form" if feature in MANUAL_ONLY else "Not recorded"})
            continue
        for concept in sources:
            obs = snapshot.get(concept)
            if obs is None:
                continue
            value = _to_model(feature, concept, obs.value)
            if value is None:
                continue
            values[feature] = value
            detail = obs.detail
            if concept == "measured.daily_steps":
                detail = f"{obs.detail}: about {obs.value:,} steps a day, so {value.lower()} activity"
            provenance.append({
                "feature": feature, "value": value, "source_value": obs.value, "concept": concept, "source": obs.source,
                "source_id": obs.source_id, "recorded_at": obs.as_dict()["recorded_at"], "detail": detail, "meta": obs.meta,
            })
            break
        else:
            reasons = [snapshot.unknown[c] for c in sources if c in snapshot.unknown]
            missing.append({"feature": feature, "reason": reasons[0] if reasons else "Not recorded"})
    return FeatureSet(values=values, provenance=provenance, missing=missing)


def merge_manual(base: FeatureSet, manual_fields: dict[str, Any]) -> FeatureSet:
    """Overlays the assessment form's answers onto the snapshot-derived FeatureSet. A manual
    answer always wins for that feature (the patient reviewed and confirmed it on the form);
    unknown fields a form doesn't cover stay exactly as the snapshot left them. Unrecognised
    keys are ignored here -- the ML client/API reject anything genuinely invalid."""
    values = dict(base.values)
    provenance = [p for p in base.provenance if p["feature"] not in manual_fields]
    missing = [m for m in base.missing if m["feature"] not in manual_fields]
    for feature, raw in manual_fields.items():
        if feature not in FEATURES or feature == "bmi" or raw is None or raw == "":
            continue
        value = _to_model(feature, "manual", raw)
        if value is None:
            continue
        values[feature] = value
        provenance.append({
            "feature": feature, "value": value, "source_value": raw, "concept": "manual", "source": "manual_entry",
            "source_id": None, "recorded_at": None, "detail": "Entered on this heart assessment", "meta": {},
        })
    still_missing = {m["feature"] for m in missing}
    for feature in FEATURES:
        if feature != "bmi" and values.get(feature) is None and feature not in still_missing:
            missing.append({"feature": feature, "reason": "Answered on the heart assessment form" if feature in MANUAL_ONLY else "Not recorded"})
    return FeatureSet(values=values, provenance=provenance, missing=missing)


def computed_bmi(values: dict[str, Any]) -> float | None:
    """BMI is never sent to the API as an input (it derives it itself from height_cm and
    weight_kg, same as the diabetes model); this is only for display/storage, computed the
    same way, so the assessment can show the BMI it was effectively based on."""
    height, weight = values.get("height_cm"), values.get("weight_kg")
    if not height or not weight:
        return None
    metres = height / 100
    return round(weight / (metres * metres), 1) if metres > 0 else None


def _to_model(feature: str, concept: str, value: Any) -> Any:
    if value is None:
        return None
    if concept == "measured.daily_steps":
        return VOCABULARY["physical_activity_level"][_activity_from_steps(float(value))]
    if feature in BINARY:
        if isinstance(value, bool):
            return 1 if value else 0
        if isinstance(value, (int, float)) and not isinstance(value, bool) and value in (0, 1):
            return int(value)
        if isinstance(value, str) and value.strip().lower() in {"yes", "true", "y", "1"}:
            return 1
        if isinstance(value, str) and value.strip().lower() in {"no", "false", "n", "0"}:
            return 0
        return None
    if feature in VOCABULARY:
        key = value.strip().lower().replace(" ", "_") if isinstance(value, str) else value
        return VOCABULARY[feature].get(key)  # anything outside the vocabulary is not sent
    if feature == "age":
        try:
            return int(value)
        except (TypeError, ValueError):
            return None
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

"""Plain-language views of heart risk assessments: which data was used (grouped by where it
came from, matching the assessment form's own sections) and what is missing. Built from the
provenance stored with each assessment, so an old assessment always shows the data it actually
used. Mirrors services/diabetes_risk/presentation.py's shape."""

from typing import Any

from ...models import HeartRiskAssessment
from ...schemas import iso
from ..health_data import profile_fields as pf
from ..health_data import snapshot as snap
from .features import BINARY, REPORT_FIELDS

FEATURE_LABELS = {
    "age": "Age", "sex": "Sex", "height_cm": "Height", "weight_kg": "Weight", "bmi": "BMI",
    "family_history_heart_disease": "Family history of heart disease", "previous_heart_disease": "Previous heart disease",
    "previous_heart_attack": "Previous heart attack", "hypertension": "High blood pressure", "diabetes": "Diabetes",
    "high_cholesterol": "High cholesterol", "kidney_disease": "Kidney disease", "stroke_history": "Previous stroke",
    "chest_pain": "Chest pain", "chest_pain_type": "Chest pain type", "chest_pain_duration_min": "Chest pain duration",
    "shortness_of_breath": "Shortness of breath", "fatigue": "Fatigue", "dizziness": "Dizziness", "fainting": "Fainting",
    "sweating": "Sweating", "nausea": "Nausea", "palpitations": "Palpitations", "pain_left_arm": "Left-arm pain",
    "pain_jaw_neck": "Jaw or neck pain", "pain_back": "Back pain",
    "resting_heart_rate": "Resting heart rate", "systolic_bp": "Systolic blood pressure", "diastolic_bp": "Diastolic blood pressure",
    "oxygen_saturation": "Oxygen saturation", "respiratory_rate": "Respiratory rate",
    "fasting_glucose": "Fasting glucose", "random_glucose": "Random glucose", "hba1c": "HbA1c",
    "total_cholesterol": "Total cholesterol", "ldl": "LDL cholesterol", "hdl": "HDL cholesterol",
    "triglycerides": "Triglycerides", "troponin": "Troponin", "hemoglobin": "Hemoglobin", "creatinine": "Creatinine",
    "resting_ecg": "Resting ECG", "ecg_abnormality": "ECG abnormality", "st_depression": "ST depression",
    "exercise_induced_angina": "Exercise-induced angina", "max_heart_rate": "Maximum heart rate (exercise)",
    "exercise_duration_min": "Exercise duration", "stress_test_result": "Stress test result",
    "echocardiogram_result": "Echocardiogram result", "ejection_fraction": "Ejection fraction",
    "heart_wall_motion_abnormality": "Heart wall motion abnormality", "previous_cardiac_test_abnormal": "Previous abnormal cardiac test",
    "smoking_status": "Smoking", "alcohol_frequency": "Alcohol", "physical_activity_level": "Physical activity",
    "sleep_hours": "Sleep", "stress_level": "Stress", "sedentary_hours_per_day": "Hours sitting per day", "diet_quality": "Diet",
}

# Groups match the assessment form's own sections (A-G in the product spec).
GROUPS = (
    ("profile", "Basic information"),
    ("medical_history", "Medical history"),
    ("symptoms", "Symptoms"),
    ("vitals", "Vitals"),
    ("report", "Laboratory values"),
    ("cardiac_tests", "Cardiac tests"),
    ("lifestyle", "Lifestyle"),
)
_GROUP_LABELS = dict(GROUPS)

FEATURE_GROUP = {
    **{f: "profile" for f in ("age", "sex", "height_cm", "weight_kg", "bmi")},
    **{f: "medical_history" for f in ("family_history_heart_disease", "previous_heart_disease", "previous_heart_attack",
                                       "hypertension", "diabetes", "high_cholesterol", "kidney_disease", "stroke_history")},
    **{f: "symptoms" for f in ("chest_pain", "chest_pain_type", "chest_pain_duration_min", "shortness_of_breath", "fatigue",
                                "dizziness", "fainting", "sweating", "nausea", "palpitations", "pain_left_arm", "pain_jaw_neck", "pain_back")},
    **{f: "vitals" for f in ("resting_heart_rate", "systolic_bp", "diastolic_bp", "oxygen_saturation", "respiratory_rate")},
    **{f: "report" for f in REPORT_FIELDS},
    **{f: "cardiac_tests" for f in ("resting_ecg", "ecg_abnormality", "st_depression", "exercise_induced_angina", "max_heart_rate",
                                     "exercise_duration_min", "stress_test_result", "echocardiogram_result", "ejection_fraction",
                                     "heart_wall_motion_abnormality", "previous_cardiac_test_abnormal")},
    **{f: "lifestyle" for f in ("smoking_status", "alcohol_frequency", "physical_activity_level", "sleep_hours",
                                 "stress_level", "sedentary_hours_per_day", "diet_quality")},
}
# Where the patient can add a missing value. Manual-only fields (symptoms, cardiac tests, and
# the heart model's own "diabetes" question) have no standalone destination -- they are only
# ever answered on the heart assessment form itself, so the Flutter side shows no "add it" link
# for them (see HeartAddDataTarget.heartAssessmentForm).
HOW_TO_ADD = {"profile": "profile", "medical_history": "health_profile", "lifestyle": "health_profile",
              "vitals": "health_connection", "report": "report_values",
              "symptoms": "heart_assessment_form", "cardiac_tests": "heart_assessment_form"}
_HOW_TO_ADD_BY_FEATURE = {"age": "profile", "sex": "profile", "height_cm": "health_profile", "weight_kg": "health_profile",
                          "diabetes": "heart_assessment_form"}

_CHOICE_LABELS = {"Former": "Used to smoke", "Current": "Smokes now", "Never": "Never"}
_UNITS = {
    "height_cm": "cm", "weight_kg": "kg", "age": "years", "bmi": "",
    "resting_heart_rate": "bpm", "systolic_bp": "mmHg", "diastolic_bp": "mmHg", "oxygen_saturation": "%", "respiratory_rate": "breaths/min",
    "fasting_glucose": "mg/dL", "random_glucose": "mg/dL", "hba1c": "%", "total_cholesterol": "mg/dL", "ldl": "mg/dL",
    "hdl": "mg/dL", "triglycerides": "mg/dL", "troponin": "ng/mL", "hemoglobin": "g/dL", "creatinine": "mg/dL",
    "chest_pain_duration_min": "min", "st_depression": "", "max_heart_rate": "bpm", "exercise_duration_min": "min",
    "ejection_fraction": "%", "sleep_hours": "h a night", "sedentary_hours_per_day": "h a day",
}


def value_label(feature: str, value: Any) -> str:
    if value is None:
        return "Not known"
    if feature in BINARY:
        return "Yes" if value == 1 else "No"
    if isinstance(value, str):
        return _CHOICE_LABELS.get(value, value.replace("_", " "))
    unit = _UNITS.get(feature, "")
    number = f"{value:g}" if isinstance(value, float) else str(value)
    return f"{number} {unit}".strip()


def _group_of(entry: dict) -> str:
    feature = entry["feature"]
    source = entry.get("source")
    if source == snap.MEDICAL_REPORT:
        return "report"
    if source == snap.WEARABLE:
        return "vitals" if feature != "physical_activity_level" else "lifestyle"
    if source == "manual_entry":
        return FEATURE_GROUP.get(feature, "symptoms")
    if source == snap.LIFESTYLE_LOG:
        return "vitals" if feature in ("resting_heart_rate", "systolic_bp", "diastolic_bp", "oxygen_saturation", "sleep_hours") else "lifestyle"
    if source == snap.HEALTH_PROFILE:
        group = (entry.get("meta") or {}).get("group")
        return {pf.BODY: "profile", pf.MEDICAL: "medical_history", pf.FAMILY: "medical_history", pf.HABITS: "lifestyle", pf.SYMPTOMS: "symptoms"}.get(group, "profile")
    return "profile"


def data_used(provenance: list[dict], missing: list[dict]) -> dict:
    groups: dict[str, list[dict]] = {key: [] for key, _ in GROUPS}
    for entry in provenance:
        feature = entry["feature"]
        groups[_group_of(entry)].append({
            "feature": feature, "label": FEATURE_LABELS.get(feature, feature), "value": value_label(feature, entry.get("value")),
            "source": entry.get("source"), "detail": entry.get("detail"), "recorded_at": entry.get("recorded_at"),
            "report_code": (entry.get("meta") or {}).get("report_code"),
        })
    return {
        "groups": [{"key": key, "label": label, "items": groups[key]} for key, label in GROUPS if groups[key]],
        "missing": [
            {"feature": m["feature"], "label": FEATURE_LABELS.get(m["feature"], m["feature"]), "reason": m.get("reason"),
             "group": FEATURE_GROUP.get(m["feature"], "symptoms"), "group_label": _GROUP_LABELS[FEATURE_GROUP.get(m["feature"], "symptoms")],
             "how_to_add": _HOW_TO_ADD_BY_FEATURE.get(m["feature"], HOW_TO_ADD[FEATURE_GROUP.get(m["feature"], "symptoms")])}
            for m in missing if m["feature"] != "bmi"
        ],
        "available_count": len(provenance),
        "total_count": len(FEATURE_LABELS) - 1,  # BMI is derived by the model API
    }


def report_fields_label(fields: list[str]) -> str | None:
    """'Troponin and HbA1c', for "Assessment used ... from your reports"."""
    names = [FEATURE_LABELS[f] for f in fields]
    names = [n if n in ("HbA1c", "LDL cholesterol", "HDL cholesterol") else n[0].lower() + n[1:] for n in names]
    if not names:
        return None
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " and " + names[-1]


def assessment_summary(a: HeartRiskAssessment) -> dict:
    return {
        "id": a.id, "code": a.assessment_code, "created_at": iso(a.created_at), "probability_percent": a.probability_percent,
        "risk_level": a.risk_level, "prediction": a.prediction, "prediction_label": a.prediction_label,
        "report_available": a.report_available, "report_fields_present": list(a.report_fields_present or []),
        "model_version": a.model_version,
    }


def assessment_out(a: HeartRiskAssessment, include_inputs: bool = False) -> dict:
    out = {
        **assessment_summary(a),
        "patient_id": a.patient_id, "decision_threshold": a.decision_threshold, "bmi": a.bmi, "warnings": list(a.warnings or []),
        "performed_by_role": a.performed_by_role, "snapshot_built_at": iso(a.snapshot_built_at),
        "report_fields_label": report_fields_label(list(a.report_fields_present or [])),
        "data_used": data_used(a.provenance or [], a.missing_features or []),
    }
    if include_inputs:
        out["input_features"] = a.input_features
    return out

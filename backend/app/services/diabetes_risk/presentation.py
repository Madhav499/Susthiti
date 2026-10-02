"""Plain-language views of assessments: which data was used (grouped by where it came from) and
what is missing. Built from the provenance stored with each assessment, so an old assessment
always shows the data it actually used."""

from typing import Any

from ...models import DiabetesRiskAssessment
from ...schemas import iso
from ..health_data import profile_fields as pf
from ..health_data import snapshot as snap
from .features import BINARY, REPORT_FIELDS

FEATURE_LABELS = {
    "age": "Age", "sex": "Sex", "height_cm": "Height", "weight_kg": "Weight", "bmi": "BMI",
    "family_history_diabetes": "Family history of diabetes", "previous_prediabetes": "Previous prediabetes",
    "previous_gestational_diabetes": "Gestational diabetes", "physical_activity_level": "Physical activity",
    "sedentary_hours_per_day": "Hours sitting per day", "diet_quality": "Diet", "sugary_drink_frequency": "Sugary drinks",
    "smoking_status": "Smoking", "alcohol_frequency": "Alcohol", "hypertension": "High blood pressure",
    "high_cholesterol": "High cholesterol", "pcos": "PCOS", "cardiovascular_disease": "Heart or blood-vessel disease",
    "fatty_liver_disease": "Fatty liver disease", "sleep_hours": "Sleep", "stress_level": "Stress",
    "polyuria": "Frequent urination", "polydipsia": "Unusual thirst", "unexplained_weight_loss": "Unexplained weight loss",
    "polyphagia": "Unusual hunger", "hba1c": "HbA1c", "fasting_glucose": "Fasting glucose", "random_glucose": "Random glucose",
    "previous_ogtt_2h": "2-hour OGTT glucose", "previous_health_report_status": "Report conclusion",
}

GROUPS = (
    ("profile", "Profile"),
    ("medical_history", "Medical history"),
    ("report", "Medical reports"),
    ("lifestyle", "Lifestyle"),
    ("wearable", "Smartwatch and health apps"),
    ("symptoms", "Symptoms"),
)
_GROUP_LABELS = dict(GROUPS)

# Where a feature belongs when it is missing, and where the patient can add it.
FEATURE_GROUP = {
    **{f: "profile" for f in ("age", "sex", "height_cm", "weight_kg", "bmi")},
    **{f: "medical_history" for f in ("family_history_diabetes", "previous_prediabetes", "previous_gestational_diabetes", "hypertension",
                                       "high_cholesterol", "pcos", "cardiovascular_disease", "fatty_liver_disease")},
    **{f: "lifestyle" for f in ("physical_activity_level", "sedentary_hours_per_day", "diet_quality", "sugary_drink_frequency",
                                 "smoking_status", "alcohol_frequency", "stress_level")},
    "sleep_hours": "wearable",
    **{f: "symptoms" for f in ("polyuria", "polydipsia", "unexplained_weight_loss", "polyphagia")},
    **{f: "report" for f in REPORT_FIELDS},
}
HOW_TO_ADD = {"profile": "profile", "medical_history": "health_profile", "lifestyle": "health_profile", "symptoms": "health_profile",
              "report": "report_values", "wearable": "health_connection"}
_HOW_TO_ADD_BY_FEATURE = {"age": "profile", "sex": "profile", "height_cm": "health_profile", "weight_kg": "health_profile"}

_CHOICE_LABELS = {
    "Never/Rarely": "Never or rarely", "1-3_per_week": "1–3 a week", "4-6_per_week": "4–6 a week",
    "Former": "Used to smoke", "Current": "Smokes now", "Never": "Never",
}
_UNITS = {"height_cm": "cm", "weight_kg": "kg", "sleep_hours": "h a night", "sedentary_hours_per_day": "h a day", "hba1c": "%",
          "fasting_glucose": "mg/dL", "random_glucose": "mg/dL", "previous_ogtt_2h": "mg/dL", "age": "years", "bmi": ""}


def value_label(feature: str, value: Any) -> str:
    if value is None:
        return "Not known"
    if feature in BINARY:
        return "Yes" if value == 1 else "No"
    if isinstance(value, str):
        return _CHOICE_LABELS.get(value, value) if feature != "sex" else value
    unit = _UNITS.get(feature, "")
    number = f"{value:g}" if isinstance(value, float) else str(value)
    return f"{number} {unit}".strip()


def _group_of(entry: dict) -> str:
    source = entry.get("source")
    if source == snap.MEDICAL_REPORT:
        return "report"
    if source in (snap.WEARABLE,):
        return "wearable"
    if source == snap.LIFESTYLE_LOG:
        return "wearable" if entry["feature"] == "sleep_hours" else "lifestyle"
    if source == snap.QUESTIONNAIRE:
        return "symptoms"
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
             "group": FEATURE_GROUP.get(m["feature"], "profile"), "group_label": _GROUP_LABELS[FEATURE_GROUP.get(m["feature"], "profile")],
             "how_to_add": _HOW_TO_ADD_BY_FEATURE.get(m["feature"], HOW_TO_ADD[FEATURE_GROUP.get(m["feature"], "profile")])}
            for m in missing if m["feature"] != "bmi"
        ],
        "available_count": len(provenance),
        "total_count": len(FEATURE_LABELS) - 1,  # BMI is derived by the model API
    }


def report_fields_label(fields: list[str]) -> str | None:
    """'HbA1c and fasting glucose', for "Assessment used ... from your reports"."""
    names = [FEATURE_LABELS[f] if f != "previous_health_report_status" else "the report's conclusion" for f in fields]
    names = [n if n in ("HbA1c",) or n.startswith("the ") else n[0].lower() + n[1:] for n in names]
    if not names:
        return None
    return names[0] if len(names) == 1 else ", ".join(names[:-1]) + " and " + names[-1]


def assessment_summary(a: DiabetesRiskAssessment) -> dict:
    return {
        "id": a.id, "code": a.assessment_code, "created_at": iso(a.created_at), "risk_percent": a.risk_percent,
        "risk_category": a.risk_category, "prediction": a.prediction, "prediction_label": a.prediction_label,
        "prediction_basis": a.prediction_basis, "report_available": a.report_available,
        "report_fields_present": list(a.report_fields_present or []), "model_version": a.model_version,
    }


def assessment_out(a: DiabetesRiskAssessment, include_inputs: bool = False) -> dict:
    out = {
        **assessment_summary(a),
        "patient_id": a.patient_id, "risk_thresholds": a.risk_thresholds or {}, "prediction_threshold": a.prediction_threshold,
        "bmi": a.bmi, "warning": a.warning, "performed_by_role": a.performed_by_role, "snapshot_built_at": iso(a.snapshot_built_at),
        "report_fields_label": report_fields_label(list(a.report_fields_present or [])),
        "data_used": data_used(a.provenance or [], a.missing_features or []),
    }
    if include_inputs:
        out["input_features"] = a.input_features
    return out

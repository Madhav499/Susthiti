from pathlib import Path
from typing import Any, Dict, Optional

import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from joblib import load
from pydantic import BaseModel, Field

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "unified_future_diabetes_model.joblib"

FEATURES = [
    "age", "sex", "height_cm", "weight_kg", "bmi",
    "family_history_diabetes", "previous_prediabetes",
    "previous_gestational_diabetes", "physical_activity_level",
    "sedentary_hours_per_day", "diet_quality", "sugary_drink_frequency",
    "smoking_status", "alcohol_frequency", "hypertension", "high_cholesterol",
    "pcos", "cardiovascular_disease", "fatty_liver_disease", "sleep_hours",
    "stress_level", "polyuria", "polydipsia", "unexplained_weight_loss",
    "polyphagia", "hba1c", "fasting_glucose", "random_glucose",
    "previous_ogtt_2h", "previous_health_report_status"
]

# These fields alone determine whether a medical report supplied usable model data.
# previous_prediabetes is deliberately NOT here: it is a risk/history factor.
REPORT_FIELDS = [
    "hba1c", "fasting_glucose", "random_glucose",
    "previous_ogtt_2h", "previous_health_report_status"
]

CATEGORICAL_VALUES = {
    "sex": {"Male", "Female"},
    "physical_activity_level": {"High", "Moderate", "Low"},
    "diet_quality": {"Good", "Average", "Poor"},
    "sugary_drink_frequency": {"Never/Rarely", "1-3_per_week", "4-6_per_week", "Daily"},
    "smoking_status": {"Never", "Former", "Current"},
    "alcohol_frequency": {"Never", "Occasionally", "Weekly", "Frequent"},
    "stress_level": {"Low", "Moderate", "High"},
    # This is the report's classification, not a generic "Available" flag.
    "previous_health_report_status": {"Normal", "Prediabetes", "Diabetes"},
}

BINARY_FIELDS = {
    "family_history_diabetes", "previous_prediabetes", "previous_gestational_diabetes",
    "hypertension", "high_cholesterol", "pcos", "cardiovascular_disease",
    "fatty_liver_disease", "polyuria", "polydipsia", "unexplained_weight_loss",
    "polyphagia"
}

app = FastAPI(
    title="SUSTHITI Unified Future Diabetes Risk API",
    description=(
        "Unified SUSTHITI future-diabetes-risk API. The same trained model handles "
        "patients with a medical report and patients without one."
    ),
    version="4.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    model = load(MODEL_PATH)
except Exception as exc:
    raise RuntimeError(f"Could not load model: {MODEL_PATH}") from exc


class PredictRequest(BaseModel):
    data: Dict[str, Any] = Field(..., description="Patient fields")


def clean_value(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, str):
        s = value.strip()
        if s.lower() in {"", "n/a", "na", "null", "none", "not available", "missing"}:
            return None
    return value


def normalize_binary(value: Any) -> Any:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)) and value in (0, 1):
        return int(value)
    if isinstance(value, str):
        s = value.strip().lower()
        if s in {"yes", "y", "true", "1"}:
            return 1
        if s in {"no", "n", "false", "0"}:
            return 0
    return value


def normalize_categories(data: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(data)
    aliases = {
        "sex": {"male": "Male", "female": "Female"},
        "physical_activity_level": {
            "high": "High", "moderate": "Moderate", "moderate activity": "Moderate",
            "modrate": "Moderate", "low": "Low", "poor": "Low"
        },
        "diet_quality": {"good": "Good", "average": "Average", "poor": "Poor"},
        "sugary_drink_frequency": {
            "never/rarely": "Never/Rarely", "never": "Never/Rarely", "rarely": "Never/Rarely",
            "1-3_per_week": "1-3_per_week", "4-6_per_week": "4-6_per_week", "daily": "Daily"
        },
        "smoking_status": {"never": "Never", "former": "Former", "current": "Current"},
        "alcohol_frequency": {"never": "Never", "occasionally": "Occasionally", "weekly": "Weekly", "frequent": "Frequent"},
        "stress_level": {"low": "Low", "moderate": "Moderate", "high": "High"},
        "previous_health_report_status": {
            "normal": "Normal", "prediabetes": "Prediabetes", "diabetes": "Diabetes"
        },
    }
    for key, mapping in aliases.items():
        if key in out and isinstance(out[key], str):
            out[key] = mapping.get(out[key].strip().lower(), out[key].strip())
    for key in BINARY_FIELDS:
        if key in out:
            out[key] = normalize_binary(out[key])
    return out


def validate(data: Dict[str, Any]) -> None:
    errors = []
    for field, allowed in CATEGORICAL_VALUES.items():
        value = data.get(field)
        if value is not None and value not in allowed:
            errors.append(f"{field} must be one of: {', '.join(sorted(allowed))}")

    for field in BINARY_FIELDS:
        value = data.get(field)
        if value is not None and value not in (0, 1):
            errors.append(f"{field} must be 0/1 or yes/no")

    numeric_nonnegative = [
        "height_cm", "weight_kg", "bmi", "sedentary_hours_per_day", "sleep_hours",
        "hba1c", "fasting_glucose", "random_glucose", "previous_ogtt_2h"
    ]
    for field in numeric_nonnegative:
        value = data.get(field)
        if value is not None:
            try:
                if float(value) < 0:
                    errors.append(f"{field} cannot be negative")
            except (TypeError, ValueError):
                errors.append(f"{field} must be numeric")

    age = data.get("age")
    if age is not None:
        try:
            if not 0 < float(age) <= 120:
                errors.append("age must be between 0 and 120")
        except (TypeError, ValueError):
            errors.append("age must be numeric")

    if errors:
        raise HTTPException(status_code=422, detail=errors)


def calculate_bmi(height_cm: Any, weight_kg: Any) -> Optional[float]:
    try:
        h, w = float(height_cm), float(weight_kg)
        if h <= 0 or w <= 0:
            return None
        return round(w / ((h / 100.0) ** 2), 2)
    except (TypeError, ValueError):
        return None


@app.get("/")
def root():
    return {
        "service": "SUSTHITI Unified Future Diabetes Risk API",
        "version": "4.0.0",
        "status": "running",
        "docs": "/docs",
        "prediction_endpoint": "/predict",
        "risk_bands": {"low": "0-40%", "moderate": ">40-65%", "high": ">65%"},
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": True,
        "model_version": "4.0.0",
        "target": "developed_diabetes_future",
        "report_detection": "Only lab/report fields determine report_available; previous_prediabetes does not.",
    }


@app.post("/predict")
def predict(request: PredictRequest):
    incoming = {k: clean_value(v) for k, v in request.data.items()}
    incoming = normalize_categories(incoming)

    # Calculate BMI if the Flutter app omits it.
    if incoming.get("bmi") is None:
        bmi = calculate_bmi(incoming.get("height_cm"), incoming.get("weight_kg"))
        if bmi is not None:
            incoming["bmi"] = bmi

    validate(incoming)

    row = {feature: incoming.get(feature, None) for feature in FEATURES}
    X = pd.DataFrame([row], columns=FEATURES)

    # CRITICAL: previous_prediabetes is a risk/history feature, not report evidence.
    present_report_fields = [
        field for field in REPORT_FIELDS
        if field in incoming and pd.notna(incoming[field])
    ]
    report_available = len(present_report_fields) > 0

    try:
        probability = float(model.predict_proba(X)[0, 1])
    except Exception as exc:
        raise HTTPException(
            status_code=422,
            detail=(
                "Prediction failed. Check categorical values and numeric values. "
                "Do not send 'Available' as previous_health_report_status; use "
                "Normal, Prediabetes, Diabetes, or leave it empty."
            ),
        ) from exc

    risk = round(probability * 100, 2)

    if risk <= 40:
        category = "Low"
    elif risk <= 65:
        category = "Moderate"
    else:
        category = "High"

    # Binary model target remains a separate model decision at 50%.
    # Risk category is based on the user's 40/65% bands.
    prediction = 1 if probability >= 0.50 else 0

    if report_available:
        basis = "symptoms_and_available_health_report"
        warning = "This is a machine-learning future-risk estimate, not a medical diagnosis."
    else:
        basis = "symptoms_and_risk_factors_only"
        warning = (
            "100% symptoms/risk-factor-based prediction because no previous medical "
            "report data was provided. This result is not fully trusted and is not a medical diagnosis."
        )

    return {
        "success": True,
        "future_diabetes_risk_percent": risk,
        "risk_category": category,
        "risk_thresholds": {
            "low": "0-40%",
            "moderate": ">40-65%",
            "high": ">65%"
        },
        "prediction": prediction,
        "prediction_label": "Higher-risk pattern" if prediction == 1 else "Lower-risk pattern",
        "prediction_threshold": "50% for binary model target",
        "prediction_basis": basis,
        "report_available": report_available,
        "report_fields_present": present_report_fields,
        "bmi": float(X["bmi"].iloc[0]) if pd.notna(X["bmi"].iloc[0]) else None,
        "model_version": "4.0.0",
        "warning": warning,
    }

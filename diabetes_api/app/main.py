import hashlib
import logging
import os
from pathlib import Path
from typing import Literal
import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ConfigDict

BASE_DIR = Path(__file__).resolve().parent
ARTIFACT_PATH = BASE_DIR / "diabetes_all_age_gender_model.joblib"

try:
    artifact = joblib.load(ARTIFACT_PATH)
    model = artifact["model"]
    FEATURE_NAMES = artifact["feature_names"]
except Exception as exc:
    raise RuntimeError(f"Could not load diabetes model artifact: {exc}") from exc

# SUSTHITI addition: a fingerprint of the exact artifact file, stored with every assessment so
# each result can be traced to the model that produced it. The artifact itself is unchanged.
MODEL_VERSION = "sha256:" + hashlib.sha256(ARTIFACT_PATH.read_bytes()).hexdigest()[:12]
log = logging.getLogger("diabetes_api")

app = FastAPI(
    title="SUSTHITI Diabetes Classification API",
    version="1.0.0",
    description=(
        "Inference API for the SUSTHITI diabetes classification prototype. "
        "This API exposes the supplied trained scikit-learn pipeline without retraining or changing it."
    ),
)

# SUSTHITI addition: the SUSTHITI backend calls this service server-to-server, so browsers need no
# access by default. Set CORS_ORIGINS (comma-separated) only if a browser client must call it.
_cors_origins = [o.strip() for o in os.environ.get("CORS_ORIGINS", "").split(",") if o.strip()]
if _cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins,
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

YesNo = Literal["Yes", "No"]
Gender = Literal["Male", "Female"]

class DiabetesInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    Age: int = Field(..., ge=16, le=90, description="Age in years")
    Gender: Gender
    Polyuria: YesNo
    Polydipsia: YesNo
    sudden_weight_loss: YesNo = Field(..., alias="sudden weight loss")
    weakness: YesNo
    Polyphagia: YesNo
    Genital_thrush: YesNo = Field(..., alias="Genital thrush")
    visual_blurring: YesNo = Field(..., alias="visual blurring")
    Itching: YesNo
    Irritability: YesNo
    delayed_healing: YesNo = Field(..., alias="delayed healing")
    partial_paresis: YesNo = Field(..., alias="partial paresis")
    muscle_stiffness: YesNo = Field(..., alias="muscle stiffness")
    Alopecia: YesNo
    Obesity: YesNo

    def to_model_dict(self) -> dict:
        return {
            "Age": self.Age,
            "Gender": self.Gender,
            "Polyuria": self.Polyuria,
            "Polydipsia": self.Polydipsia,
            "sudden weight loss": self.sudden_weight_loss,
            "weakness": self.weakness,
            "Polyphagia": self.Polyphagia,
            "Genital thrush": self.Genital_thrush,
            "visual blurring": self.visual_blurring,
            "Itching": self.Itching,
            "Irritability": self.Irritability,
            "delayed healing": self.delayed_healing,
            "partial paresis": self.partial_paresis,
            "muscle stiffness": self.muscle_stiffness,
            "Alopecia": self.Alopecia,
            "Obesity": self.Obesity,
        }

class PredictionResponse(BaseModel):
    prediction: Literal["Positive", "Negative"]
    classification_probability: float = Field(..., ge=0, le=1)
    interpretation: str
    model_name: str
    model_version: str
    disclaimer: str

@app.get("/")
def root():
    return {"service": "SUSTHITI Diabetes Classification API", "status": "ok", "docs": "/docs"}

@app.get("/health")
def health():
    return {"status": "healthy", "model_loaded": True, "model_name": artifact.get("model_name"), "model_version": MODEL_VERSION}

@app.get("/model-info")
def model_info():
    return {
        "model_name": artifact.get("model_name"),
        "model_version": MODEL_VERSION,
        "feature_names": FEATURE_NAMES,
        "target_mapping": artifact.get("target_mapping"),
        "validation": artifact.get("validation"),
        "dataset_info": artifact.get("dataset_info"),
        "limitation": artifact.get("limitation"),
    }

@app.post("/predict", response_model=PredictionResponse)
def predict(payload: DiabetesInput):
    try:
        row = pd.DataFrame([payload.to_model_dict()], columns=FEATURE_NAMES)
        prediction = int(model.predict(row)[0])
        probability = float(model.predict_proba(row)[0][1])
    except Exception as exc:
        # SUSTHITI change: log the cause server-side; never return Python exception text to clients.
        log.exception("model inference failed")
        raise HTTPException(status_code=500, detail="Model inference failed.") from exc

    return PredictionResponse(
        prediction="Positive" if prediction == 1 else "Negative",
        classification_probability=probability,
        interpretation=(
            "Diabetes-related pattern detected by the model"
            if prediction == 1
            else "No diabetes-related pattern detected by the model"
        ),
        model_name=artifact.get("model_name", "SVM RBF"),
        model_version=MODEL_VERSION,
        disclaimer=(
            "This is a machine-learning classification/screening result, not a medical diagnosis "
            "and not a prediction of future diabetes onset. Consult a qualified healthcare professional."
        ),
    )

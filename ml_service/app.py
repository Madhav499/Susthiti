"""SUSTHITI diabetes ML service. Wraps the supplied .joblib; loaded once at startup."""

import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException

from predictor import DEFAULT_CONFIG_PATH, DEFAULT_MODEL_PATH, DiabetesPredictor, ModelNotReady
from schemas import FEATURES, PredictRequest, PredictResponse

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")

predictor = DiabetesPredictor(
    Path(os.environ.get("MODEL_PATH", DEFAULT_MODEL_PATH)),
    Path(os.environ.get("MODEL_CONFIG_PATH", DEFAULT_CONFIG_PATH)),
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    predictor.load()
    yield


app = FastAPI(title="SUSTHITI ML service", version="1.0.0", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok" if predictor.ready else "model_not_loaded", "model_version": predictor.version if predictor.ready else None, "detail": predictor.error, "features": list(FEATURES)}


@app.post("/predict", response_model=PredictResponse)
def predict(body: PredictRequest):
    try:
        result = predictor.predict(body.as_features())
    except ModelNotReady as exc:
        raise HTTPException(status_code=503, detail={"code": "model_not_loaded", "message": str(exc)})
    return PredictResponse(prediction=result.prediction, classification_probability=result.classification_probability, model_version=result.model_version)

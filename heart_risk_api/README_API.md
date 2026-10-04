# SUSTHITI Heart Disease Risk API v3 (private service)

Supplied, pre-trained model (`susthiti-heart-v3`): Extra Trees Classifier, 600 trees,
min_samples_leaf 2, `balanced_subsample` class weighting, Platt/sigmoid probability
calibration, decision threshold 0.3275. Trained on a **20,000-row synthetic dataset**.

This model, its preprocessing, and its threshold are used exactly as supplied. It is not
retrained, not re-thresholded, and not represented as clinically validated anywhere in
SUSTHITI. See the project's `ML_MODEL_SETUP.md` and `AI_ARCHITECTURE.md` for how results
flow into the backend and AI summaries, always labeled as a screening signal, never a
diagnosis.

## Run locally

```bash
python -m venv .venv
.venv\Scripts\activate   # Windows
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8002
```

SUSTHITI's local dev script (`scripts/start-susthiti.ps1`) starts this service on port
**8002**, alongside the diabetes risk API on 8001 and the backend on 8000.

## Endpoints

- `GET /health` -> `{"status": "ok", "model_version": "susthiti-heart-v3"}`
- `GET /model-info` -> feature list (authoritative order), threshold, training metrics
- `POST /predict` -> body `{"data": {...}}`, response includes `prediction`,
  `prediction_label`, `probability`, `probability_percent`, `risk_level`,
  `decision_threshold`, `model_version`, `warnings`, `disclaimer`

Only send fields SUSTHITI actually knows; the pipeline imputes the rest. Never send a
guessed/defaulted value for an unknown field -- omit it instead.

## Deployment

Same pattern as `diabetes_risk_api/`: a private service reachable only by the SUSTHITI
backend, never exposed publicly (it has no authentication of its own). See `DEPLOY.md`.

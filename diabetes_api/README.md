# SUSTHITI Diabetes Classification API

FastAPI wrapper around the supplied `diabetes_all_age_gender_model.joblib` artifact.
The API does **not** retrain, alter, or approximate the model. It loads the serialized
scikit-learn preprocessing + RBF SVM pipeline and sends the validated input through it.

## Run locally

```bash
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Swagger UI: `http://127.0.0.1:8000/docs`

## Endpoints

- `GET /health` — service/model health
- `GET /model-info` — artifact metadata, features and validation information
- `POST /predict` — diabetes classification inference

## POST /predict example

```json
{
  "Age": 45,
  "Gender": "Male",
  "Polyuria": "Yes",
  "Polydipsia": "Yes",
  "sudden weight loss": "No",
  "weakness": "Yes",
  "Polyphagia": "Yes",
  "Genital thrush": "No",
  "visual blurring": "Yes",
  "Itching": "No",
  "Irritability": "No",
  "delayed healing": "Yes",
  "partial paresis": "No",
  "muscle stiffness": "No",
  "Alopecia": "No",
  "Obesity": "Yes"
}
```

The response contains `prediction`, `classification_probability`, `interpretation`, `model_name`, and `disclaimer`.

## Important model limitation

The artifact documentation states that the dataset has a current `Positive`/`Negative` class label rather than a future follow-up outcome. Therefore this API exposes the model as a current diabetes-related classification/screening prototype. Do not present its probability as a 1-year/5-year/10-year future-onset probability or as a medical diagnosis.

## Production notes

- Put the API behind HTTPS.
- Restrict CORS to the SUSTHITI production domains.
- Add authentication/API gateway controls before exposing it publicly.
- Add request logging without storing unnecessary health information.
- Keep the model artifact versioned and immutable; record the model version with prediction history.
- For patient records, use server-side authorization so a user can only access permitted records.

## SUSTHITI integration notes

- Run on port **8001** (`uvicorn app.main:app --port 8001`); the SUSTHITI backend runs on 8000 and reaches this
  service through `ML_SERVICE_URL`. The Flutter app never calls this service directly.
- `scikit-learn` is pinned to **1.8.0**, the version that saved the artifact.
- Changes to `app/main.py` (the model, its loading and the inference lines are unchanged):
  - adds `model_version` (`sha256:` + first 12 hex digits of the artifact file) to `/health`, `/model-info` and
    `/predict`, so every saved assessment records exactly which file produced it;
  - a failed inference returns a generic `"Model inference failed."` and logs the cause server-side, instead of
    returning the Python exception text;
  - CORS is off unless `CORS_ORIGINS` (comma-separated) is set, because only the SUSTHITI backend calls it.
- `tests/test_api.py` keeps the original three tests and adds nine more (age bounds, invalid values, missing and
  extra fields, `/model-info`, wording, determinism, error-text leakage, CORS).

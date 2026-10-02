# Diabetes model setup

> **Current model: SUSTHITI Future Diabetes Risk API v4.0.0** in [`diabetes_risk_api/`](diabetes_risk_api/README_API.md)
> (`unified_future_diabetes_model.joblib`). It estimates future diabetes risk from the health data SUSTHITI already
> holds; see **[docs/diabetes-api-v4-integration.md](docs/diabetes-api-v4-integration.md)**. The 16-question model
> described below (`diabetes_api/`) is **superseded**: it is no longer started or deployed, and its past assessments
> remain in patients' history as read-only records.

SUSTHITI uses **only** the supplied `diabetes_all_age_gender_model.joblib`, served by the supplied
**SUSTHITI Diabetes Classification API** in [`diabetes_api/`](diabetes_api/README.md). The model is not retrained,
replaced, approximated or re-implemented anywhere. The Flutter app never contains the model and never calls
the model service directly.

```text
Flutter app  --HTTPS + sign-in-->  SUSTHITI backend (backend/)  --HTTP-->  diabetes_api (FastAPI)  -->  .joblib
                                   authorizes, validates, saves              loads the artifact,
                                   each assessment, audits it                predict + predict_proba
```

> `ml_service/` is the earlier placeholder service. It expected a bare model object and cannot load the
> supplied artifact (a dictionary with the pipeline plus metadata). It is **superseded** by `diabetes_api/` and
> is no longer used. It can be deleted.

## The artifact

| Item | Value |
| --- | --- |
| File | `diabetes_api/app/diabetes_all_age_gender_model.joblib` (SHA-256 `844d428a…`) |
| Contents | dict: `model`, `feature_names`, `model_name`, `target_mapping`, `validation`, `dataset_info`, `limitation` |
| Pipeline | `ColumnTransformer` (StandardScaler on Age, OneHotEncoder on the 15 categories) -> RBF `SVC` with probabilities |
| Saved with | scikit-learn **1.8.0**, pinned exactly in `diabetes_api/requirements.txt` |
| Target | `Negative = 0`, `Positive = 1` |
| Ages covered | 16 to 90 |
| Version recorded per assessment | `sha256:844d428af0a3` (fingerprint of the file, reported by the API) |

## The 16 inputs

Exact API field names (Dart uses idiomatic names; `DiabetesPredictionRequest.toJson()` maps them):
`Age` (whole number 16-90), `Gender` (`Male` / `Female`), and `Yes` / `No` for `Polyuria`, `Polydipsia`,
`sudden weight loss`, `weakness`, `Polyphagia`, `Genital thrush`, `visual blurring`, `Itching`, `Irritability`,
`delayed healing`, `partial paresis`, `muscle stiffness`, `Alopecia`, `Obesity`.

Validated three times: in the app (form), in the backend (`services/diabetes_model.py`, before the model is
called) and in the API (pydantic, `extra="forbid"`). Out-of-range values are rejected with a message, never adjusted.

## Run it locally

```bash
cd diabetes_api
python -m venv .venv            # Python 3.12 or 3.13
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8001
curl http://127.0.0.1:8001/health   # {"status":"healthy","model_loaded":true,...,"model_version":"sha256:844d428af0a3"}
```

The backend finds it through `ML_SERVICE_URL` in `backend/.env` (default `http://127.0.0.1:8001`) and waits up to
`ML_SERVICE_TIMEOUT_SECONDS` (default 15) for a result. Port 8001 is used because the backend runs on 8000.

## Output and wording

`POST /predict` returns `prediction`, `classification_probability`, `interpretation`, `model_name`,
`model_version` and `disclaimer`. The backend stores all of them with the 16 inputs as a new, never-overwritten
assessment.

`classification_probability` is `predict_proba(...)[0][1]`: **the model's probability for the Positive class**.
A Negative result therefore comes with a low value (for example 2%). The app labels it "Model classification
probability" with that explanation, shows values above 99.5% / below 0.5% as ">99%" / "<1%", and never presents it
as a diagnosis, a disease probability or a chance of developing diabetes. Results are worded
"Diabetes-related pattern detected" / "No diabetes-related pattern detected".

## Errors

| Situation | Backend response | What the patient sees |
| --- | --- | --- |
| Service not reachable | 503 `model_service_unavailable` | "The assessment service is temporarily unavailable..." |
| Too slow | 504 `model_service_timeout` | "The assessment took too long to complete..." |
| Service error / malformed reply | 502 `model_inference_failed` | "We couldn't process the assessment right now. Your answers have not been treated as a diagnosis..." |
| Inputs rejected | 422 `validation_error` | "Please review your answers and try again." |

Nothing is saved when an assessment fails, and the entered answers stay on screen for Try Again. Python
exception text is never returned by the API or shown in the app.

## Tests

```bash
cd diabetes_api && .venv\Scripts\python -m pytest     # 12 tests against the real artifact
cd backend && .venv\Scripts\python -m pytest          # uses a TEST-ONLY fake of the API's responses
cd app && flutter test
```

## Production

- Run `diabetes_api` as its own service (its `Dockerfile` bundles the artifact) on a private network reachable
  only by the SUSTHITI backend; point `ML_SERVICE_URL` at it. Do not expose it publicly: it has no user
  authentication of its own. Authorization happens in the SUSTHITI backend.
- Leave `CORS_ORIGINS` unset (browsers never call it). Serve the SUSTHITI backend over HTTPS.
- Keep the artifact immutable. A new model file gets a new `model_version` automatically, so every saved
  assessment stays traceable to the file that produced it.

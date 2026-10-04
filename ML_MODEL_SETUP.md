# ML model setup

SUSTHITI runs two independent, supplied ML services behind the backend. Neither is retrained,
replaced, approximated or re-implemented anywhere, and the Flutter app never contains a model
or calls a model service directly -- only the backend does, after authorizing the request.

| | Diabetes risk | Heart disease risk |
| --- | --- | --- |
| Service directory | [`diabetes_risk_api/`](diabetes_risk_api/README_API.md) | [`heart_risk_api/`](heart_risk_api/README_API.md) |
| Model version | `4.0.0` (`unified_future_diabetes_model.joblib`) | `susthiti-heart-v3` (`model.joblib`) |
| Algorithm | gradient-boosted pipeline (see the API's own README) | Extra Trees Classifier, 600 trees, Platt-calibrated |
| Training data | SUSTHITI's own future-risk dataset | **20,000-row SYNTHETIC dataset** -- see below |
| Local port | 8001 | 8002 |
| Backend env var | `ML_SERVICE_URL` | `HEART_MODEL_SERVICE_URL` |
| Backend client | `backend/app/services/diabetes_risk/` | `backend/app/services/heart_risk/` |
| Stored assessment table | `diabetes_risk_assessments` | `heart_risk_assessments` |

```text
Flutter app --HTTPS+sign-in--> SUSTHITI backend --HTTP--> diabetes_risk_api (FastAPI) --> unified_future_diabetes_model.joblib
                                 authorizes,     --HTTP--> heart_risk_api    (FastAPI) --> model.joblib
                                 validates, saves
                                 each assessment,
                                 audits it
```

> **Superseded, not deleted.** `diabetes_api/` (the earlier 16-question symptom model) and
> `ml_service/` (an abandoned placeholder that cannot load the production artifact) are no
> longer started or deployed. `diabetes_api`'s past assessments remain in patients' history as
> read-only records (`DiabetesAssessment`); nothing from either directory runs in production.

## Diabetes risk (`diabetes_risk_api/`)

Estimates **future** diabetes risk from the health data SUSTHITI already holds (profile,
confirmed report values, lifestyle/wearable data, health-profile answers) -- not a diagnosis.
`backend/app/services/diabetes_risk/features.py` is the **only** place that decides how
SUSTHITI's data maps to the model's 30 input fields; a feature is sent only when genuinely
known, never defaulted. See that module's docstring and `backend/app/services/diabetes_risk/`
generally for the client/feature-builder/coordinator pattern every risk model in this repo
follows (the heart service below mirrors it exactly).

Run it locally:
```bash
cd diabetes_risk_api
python -m venv .venv
.venv\Scripts\activate          # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 127.0.0.1 --port 8001
curl http://127.0.0.1:8001/health
```

## Heart disease risk (`heart_risk_api/`)

**Supplied, pre-trained model `susthiti-heart-v3`**: Extra Trees Classifier, 600 trees,
`min_samples_leaf=2`, `balanced_subsample` class weighting, Platt/sigmoid probability
calibration, decision threshold **0.3275**. Trained on a **20,000-row SYNTHETIC dataset**.
Validation metrics (on synthetic held-out data, see `heart_risk_api`'s packaged metrics):
accuracy 83.98%, balanced accuracy 79.58%, precision 64.13%, sensitivity 71.34%, specificity
87.83%, F1 67.54%, ROC-AUC 88.38%.

**This is a screening signal for the SUSTHITI project/software, not a clinical diagnostic
tool.** It must never be presented as clinically validated or as a confirmed diagnosis --
enforced in the backend's `services/ai/safety.py` (regex-checked AI output) and in the
Flutter `HeartWording` class (`app/lib/data/models/heart_risk.dart`), which is the single
source of the screening/disclaimer wording shown anywhere in the app.

The model exposes 59 input fields (50 numeric/binary, 9 categorical) covering basic
information, medical history, symptoms, vitals, laboratory values, cardiac tests and
lifestyle. `backend/app/services/heart_risk/features.py` maps SUSTHITI's data to them, split
into:
- **Reusable** fields (age, sex, height/weight, hypertension, high cholesterol, family/
  medical history additions, smoking/alcohol/activity/diet/sleep, and lab values confirmed
  from an uploaded report) -- read from the same patient-profile/report/wearable system the
  diabetes model uses, via new `profile_fields.py` entries and new `report_values.py`
  analytes (total cholesterol, LDL, HDL, triglycerides, troponin, hemoglobin, creatinine).
- **Manual-only** fields (symptoms, cardiac test results, and the model's own `diabetes`
  yes/no field) -- point-in-time answers from the heart assessment form; never prefilled,
  never inferred from the diabetes risk estimate, never written back into the durable health
  profile. See `features.MANUAL_ONLY` for the exact list.

The backend client (`services/heart_risk/client.py`) cross-checks the model's authoritative
`/model-info` feature list against the hand-written `FEATURES` constant the first time it
connects, so a future model update that renames/adds a field is caught loudly (a
`model_version_unsupported` error) instead of silently sending the wrong data.

Run it locally:
```bash
cd heart_risk_api
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 127.0.0.1 --port 8002
curl http://127.0.0.1:8002/health
curl http://127.0.0.1:8002/model-info
```

### Endpoints (both services)

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/health` | `{"status": "ok", ...}` |
| GET | `/model-info` | Feature list, threshold, training metrics |
| POST | `/predict` | Body `{"data": {...}}`; unknown fields imputed, never guessed by SUSTHITI itself |

The backend finds each service through its own env var (`ML_SERVICE_URL` /
`HEART_MODEL_SERVICE_URL` in `backend/.env`) and the aggregate `GET /health` on the backend
reports both (`model_service` / `heart_model_service`, each `ok | not_ready | unreachable |
unsupported_version`).

## Errors (both services, same backend convention)

| Situation | Backend response | What the user sees |
| --- | --- | --- |
| Service not reachable | 503 `model_service_unavailable` | "...unavailable right now. Please try again later." |
| Too slow | 504 `model_service_timeout` | "...took too long to complete. Please try again." |
| Service error / malformed reply | 502 `model_inference_failed` | "We couldn't process the assessment/screening right now..." |
| Inputs rejected | 422 `validation_error` | Field-level message, no patient values leaked |

Nothing is saved when a prediction fails. Python exception text is never returned by either
API or shown in the app.

## Tests

```bash
cd backend && .venv\Scripts\python -m pytest tests/test_diabetes_risk.py tests/test_heart_risk.py tests/test_ai_heart.py
cd app && flutter test
```
Both model services' test doubles (`FakeRiskAPI`, `FakeHeartRiskAPI` in `backend/tests/conftest.py`)
follow their real API's contract; only the prediction number is fake.

## Production

- Run each model service as its own process/container on a private network reachable only by
  the SUSTHITI backend; point `ML_SERVICE_URL` / `HEART_MODEL_SERVICE_URL` at it. **Do not
  expose either publicly** -- neither has its own authentication; authorization happens in
  the SUSTHITI backend. See `deploy/docker-compose.yml` for the self-hosted pattern (a
  `heart-model` service alongside the existing `model` service) and `DEPLOY.md`.
- If deploying on Render: add the heart service as its own Render Web Service the same way
  the diabetes model service is deployed there today, and set `HEART_MODEL_SERVICE_URL` on
  the backend service to its internal URL. There is no `render.yaml` in this repo -- Render
  services are configured in the dashboard, so this is a manual step.
- Keep each artifact immutable. A new model file gets a new model version automatically, so
  every saved assessment stays traceable to the file that produced it.

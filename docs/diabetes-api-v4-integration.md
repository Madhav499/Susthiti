# Future diabetes risk — SUSTHITI Diabetes Risk API v4 integration

SUSTHITI estimates a patient's **future diabetes risk** with the supplied SUSTHITI Unified Future
Diabetes Risk API **v4.0.0** (`diabetes_risk_api/`). The model estimates risk from the health
information SUSTHITI **already holds** about the patient: there is no diabetes questionnaire.

> The model is an ML research/screening prototype trained on synthetic data. It is not clinically
> validated and is not a medical diagnosis. SUSTHITI always presents it as a *model-estimated
> future risk* — never "you have diabetes", "you will develop diabetes" or "you are safe".

## 1. Architecture

```text
Patient profile (DOB, sex) ─┐
Health profile ─────────────┤  body, medical & family history, habits, recent symptoms (health_facts)
Report values ──────────────┤  confirmed on uploaded reports (report_values)
Lifestyle / smartwatch ─────┤  sleep & steps from Health Connect / Apple Health / manual logs
Earlier questionnaire ──────┘  symptom answers < 90 days old (read-only history)
            │
            ▼
backend/app/services/health_data/snapshot.py      build_snapshot()  -> PatientHealthSnapshot
            │                                      (value + source + time + reason if unknown)
            ▼
backend/app/services/diabetes_risk/features.py    build_features()  -> 30 API fields + provenance
            ▼
backend/app/services/diabetes_risk/client.py      DiabetesRiskApiV4Client: GET /health, POST /predict,
            │                                      strict response validation
            ▼
backend/app/services/diabetes_risk/coordinator.py  store immutable DiabetesRiskAssessment, staleness
            ▼
Flutter: Diabetes tab · dashboard · doctor & admin patient views · timeline · detail screen
```

* **The app never calls the model.** Flutter talks to the SUSTHITI backend (signed in, authorized);
  only the backend calls API v4, which has no authentication of its own and is kept private
  (`127.0.0.1:8001` locally, the private Docker network on a server).
* **Only the model's fields are sent.** Never names, email, phone, codes, report files or any other
  patient data (`FeatureSet.request_data()` holds known model features only).
* The health data layer is **not diabetes-specific**: a future model gets its own feature builder
  over the same `PatientHealthSnapshot`.

## 2. API contract (v4.0.0, `diabetes_risk_api/main.py`, used unmodified)

| | |
|---|---|
| `GET /health` | `{"status":"ok","model_loaded":true,"model_version":"4.0.0",...}` — checked before every prediction |
| `POST /predict` | body `{"data": {<feature>: <value>, ...}}`; unknown features omitted |
| Response | `success, future_diabetes_risk_percent, risk_category, risk_thresholds, prediction, prediction_label, prediction_threshold, prediction_basis, report_available, report_fields_present, bmi, model_version, warning` |
| Risk bands | Low 0–40 %, Moderate >40–65 %, High >65 % (from the API; SUSTHITI never recomputes them) |
| Prediction | separate 50 % model decision: "Higher-risk pattern" / "Lower-risk pattern" |
| Report detection | only `hba1c, fasting_glucose, random_glucose, previous_ogtt_2h, previous_health_report_status` — **`previous_prediabetes` is never report evidence** |

The only change to the supplied package is pinning versions in `requirements.txt`: the model was
saved with scikit-learn **1.8.0**, which is pinned exactly.

## 3. Feature mapping and source priority

| API field | Source (first usable wins) | Freshness | Notes |
|---|---|---|---|
| age | patient profile date of birth | calculated today | never stored |
| sex | patient profile gender | — | Male / Female only |
| height_cm | health profile | until changed | |
| weight_kg | health profile (latest entry) | 365 days | |
| bmi | — | — | **left to the API** (computed from height & weight) |
| family_history_diabetes | health profile | until changed | 1 / 0; "not sure" = unknown |
| previous_prediabetes, previous_gestational_diabetes, hypertension, high_cholesterol, pcos, cardiovascular_disease, fatty_liver_disease | health profile (medical history) | until changed | gestational & PCOS asked only for women |
| physical_activity_level | 1. smartwatch/lifestyle daily steps; 2. health profile self-report | steps: last 14 days, ≥ 7 days recorded; answer: 180 days | steps: < 5,000 Low · 5,000–9,999 Moderate · ≥ 10,000 High (Tudor-Locke & Bassett step bands) |
| sedentary_hours_per_day | health profile | 180 days | no measured source exists |
| diet_quality, sugary_drink_frequency | health profile | 180 days | free-text food logs are **not** converted into a diet score |
| smoking_status, alcohol_frequency | health profile | 365 days | |
| sleep_hours | smartwatch / lifestyle sleep | last 14 days, ≥ 3 nights | average hours a night |
| stress_level | health profile | 90 days | |
| polyuria, polydipsia, unexplained_weight_loss, polyphagia | 1. health profile symptoms; 2. earlier symptom questionnaire | 90 days | |
| hba1c, fasting_glucose, random_glucose, previous_ogtt_2h | values confirmed on uploaded reports | newest report; reports > 2 years old not used | glucose stored in mg/dL (mmol/L × 18.0182) |
| previous_health_report_status | report conclusion confirmed on a report | as above | only `Normal` / `Prediabetes` / `Diabetes`, read off the report — never inferred from numbers, never "Available" |

**Never used**: heart rate, SpO₂, blood pressure, calories, food logs and home glucometer readings
have no legitimate mapping to a model field. Blood pressure readings never set `hypertension`.
Demo data (`is_demo`) is never health data.

**Unknown stays unknown.** A value is sent only when it is genuinely known. "Not sure", unanswered,
expired or insufficient data are omitted (the API's preprocessing handles missing values) and are
listed with the reason in the "Not recorded yet" section.

## 4. Reports

Uploaded reports are files; SUSTHITI had no structured lab extraction. Values become health data
once confirmed on the report they came from (`PUT /reports/{id}/values`), by the patient or a
doctor, and are reused everywhere after that — never asked for again.

* **AI suggestions**: when an AI report summary exists, its `relevant_values` are offered as
  suggestions only if the name matches a known name exactly (no fuzzy matching), the value is one
  plain number, and the unit is convertible. Conflicting values for one measure are not suggested.
  Suggestions count only after someone confirms them (`origin = ai_suggestion`, kept in provenance).
* **Report recency**: per measure, the newest report date wins, then the latest confirmation. The
  previous value is kept as history. Values are append-only (corrections supersede, never delete).

## 5. Assessments, staleness and refresh policy

* Stored in `diabetes_risk_assessments`, **immutable**: the API response as returned, the exact
  features sent (`input_features`), provenance per feature, missing features, model version,
  snapshot time, and an input fingerprint.
* **Reading never runs the model.** `GET /patients/{id}/diabetes-risk` compares the stored
  fingerprint with the patient's current data and returns `stale` plus reasons.
* The fingerprint uses meaningful precision (weight/height 1, sleep/sitting hours 0.5; everything
  else exact), so daily noise doesn't flag an assessment as out of date; a new report value,
  a profile answer, a birthday, a new activity band or a new model major version does.
* **Refresh** (`POST`): patient or doctor with access. If nothing changed, the existing assessment is
  returned (`200`, `created: false`) and the model is not called. Otherwise `/health` is checked,
  `/predict` is called, and a new record is created (`201`). Nothing is ever called for a smartwatch
  sync or a dashboard load.
* The legacy 16-question model's assessments stay readable as history ("Earlier symptom questionnaire").

## 6. Endpoints

| Method | Path | Who |
|---|---|---|
| GET | `/patients/{id}/diabetes-risk` | patient, doctor with access, admin (read) |
| POST | `/patients/{id}/diabetes-risk` | patient, doctor with access |
| GET | `/patients/{id}/diabetes-risk/history` | readers |
| GET | `/diabetes-risk/{assessment_id}` | readers (includes `input_features`) |
| GET / PUT | `/patients/{id}/health-profile` | read: readers; write: patient, doctor with access |
| GET / PUT | `/reports/{id}/values` | read: readers; write: patient, doctor with access |

Every write is audited (field names only, never values).

## 7. Errors and validation

| Situation | Result |
|---|---|
| Model service down / refused / DNS | 503 `model_service_unavailable`; nothing stored; last assessment still shown |
| Timeout | 504 `model_service_timeout` |
| `/health` not ok or model not loaded | 503, `/predict` is not called |
| Unsupported API version (not 4.x) | 502 `model_version_unsupported` |
| 422 from the API | 422 with the API's field messages (SUSTHITI validates vocabularies first, so this indicates a contract change) |
| Malformed or inconsistent response (risk out of 0–100, unknown category/basis, report fields not matching what was sent…) | 502 `model_inference_failed`; nothing stored |

The app shows calm messages; offline, the signed-in patient sees their own last status (secure
device storage), clearly marked, with "Connect to the internet to update your assessment" when new
data is waiting.

## 8. Configuration

| Setting | Where | Default |
|---|---|---|
| `ML_SERVICE_URL` | `backend/.env` | `http://127.0.0.1:8001` |
| `ML_SERVICE_TIMEOUT_SECONDS` | `backend/.env` | 15 |
| `API_BASE_URL` (app → backend) | `--dart-define` | emulator `10.0.2.2`, web `localhost`, USB phone `127.0.0.1` (adb reverse), Wi-Fi phone `app/config/dev_phone.json`, server `https://…` |

Run API v4 locally (the launcher does this): `cd diabetes_risk_api && .venv\Scripts\python -m uvicorn main:app --host 127.0.0.1 --port 8001`.
Port 8001 (not the README's 8000) because the SUSTHITI backend uses 8000, and `127.0.0.1` because
only the backend should reach it. On a server it runs in the `model` container (`deploy/docker-compose.yml`).

## 9. Tests

* `diabetes_risk_api/tests` — 13 contract tests on the real model: report detection (each report
  field alone; `previous_prediabetes` alone is *not* a report), null fields, "Available" rejected, bands.
* `backend/tests/test_diabetes_risk.py` — 36 tests: profile-only, each report field, previous
  prediabetes, **golden requests identical to `test_request_report.json` / `test_request_no_report.json`**
  built from patient data, not-sure ≠ no, invalid values refused, only model fields sent, wearable
  sleep/steps (and nothing from heart rate, SpO₂, BP), insufficient/stale/demo data, questionnaire
  reuse, report recency and 2-year cut-off, strict AI suggestions, corrections, unchanged refresh,
  staleness reasons, immutability, model unavailable, malformed/inconsistent/unsupported responses,
  doctor/admin access, dashboard/timeline/admin, freshness expiry.
* `app/test/unit/diabetes_risk_test.dart`, `app/test/widget/diabetes_risk_view_test.dart` — models,
  wording (never "normal" without a report), offline cache (own record only), and every screen state.
* A live end-to-end run on the real model reproduced the API's own results for both samples
  (10.2 % with report, 16.18 % without) from equivalent patient data.

# Architecture

```
 Flutter app (patient / doctor / admin)
        │  HTTPS, Bearer session token
        ▼
 backend (FastAPI)  ──────────►  diabetes_risk_api (FastAPI + supplied .joblib, model v4)
   │  auth, roles, records            POST /predict  (30 exact inputs, only genuinely known ones sent)
   │  private file storage
   │  notifications, audit    ──────────►  heart_risk_api (FastAPI + supplied .joblib, model susthiti-heart-v3)
   │  PDF generation                       POST /predict  (59 exact inputs; SYNTHETIC-data model, screening only)
   └──────────────►  OpenRouter (OpenAI-compatible chat completions, key from backend env only)
```

The app never talks to either ML service or to OpenRouter directly. Every request goes through the backend,
which checks the caller's role and relationship to the patient first. The two ML services are independent
siblings (separate processes, separate backend client/coordinator modules, separate database tables) -- neither
can affect the other.

## Flutter app (`app/lib`)

Feature-based clean architecture with Riverpod.

| Layer | Folder | Notes |
| --- | --- | --- |
| Core | `core/` | Theme and design tokens, `ApiClient` (dio), typed `Failure`s, secure token storage, validators, shared widgets, router |
| Data | `data/models`, `data/repositories`, `data/services`, `data/datasources`, `data/providers.dart` | One repository per area (Report, Diabetes, Glucose, Food, Lifestyle, Wearable, Prescription, SideEffect, Visit, Notification, Patient, Doctor, Admin, Auth). Services: `ReportAIService`, `PatientAIService`, `LifestyleAIService`, `AIRepository`, `DiabetesModelService`, `FileStorageService`, `PDFService`, `WearableService` |
| Features | `features/<area>/` | Screens and their providers: authentication, patient, reports, diabetes, heart, glucose, food, lifestyle, wearables, side_effects, prescriptions, visits, access, doctor, admin, ai, notifications, settings |

Key points:

- **Single source of truth for model inputs**: `features/diabetes/diabetes_features.dart` lists the 16 model
  columns with their exact names and order. The questionnaire, validation, request building and history
  views all read from it.
- **Routing** (`core/routing/app_router.dart`): `/p/...` patient, `/d/...` doctor, `/a/...` admin, and shared
  record screens under `/r/:patientId/...`. `roleRedirect` keeps each role in its own area; patients can only
  open `/r/` routes for their own ID; admins may open any `/r/` record screen read-only (but not the clinical
  upload route). The backend enforces the same rules.
- **Responsive shells**: bottom navigation on phones, a navigation rail on tablets and an extended sidebar on
  desktop. Content width is capped so cards never stretch across a wide screen.
- **Errors**: `ApiClient` maps every failure to a typed `Failure` (Network, Timeout, Authentication,
  Authorization, Validation, NotFound, Conflict, FileUpload, AIService, ModelService, Database, Unexpected).
  Screens show what happened, what the user can do and a Try Again button when retrying makes sense.
- **No automatic retries**: `ProviderScope(retry: ...)` is disabled so failures surface immediately.
- **Design**: palette and Inter font are defined in `core/theme`. Inter is bundled as an asset, so no fonts
  are fetched at runtime.

## Backend (`backend/app`)

| Module | Responsibility |
| --- | --- |
| `routers/auth.py` | Patient registration, login, logout, password reset and change. Sessions are revocable database rows referenced by a signed JWT |
| `deps.py` | `get_current_user`, `require_roles`, and `authorize_patient` (patient: self only; doctor: approved access only; admin: any patient, read-only via `require_record_reader`) |
| `routers/reports.py`, `services/storage.py` | Upload with type sniffing, size limit and SHA-256; files stored under opaque references and served only via `/reports/{id}/file` after authorization |
| `routers/diabetes.py` | Read-only history of the earlier, superseded 16-question symptom model |
| `routers/diabetes_risk.py`, `services/diabetes_risk/` | Builds the current model's 30 inputs only from genuinely known data (never defaulted), calls `diabetes_risk_api`, stores an immutable assessment with full provenance |
| `routers/heart_risk.py`, `services/heart_risk/` | Same pattern, sibling model: 59 inputs (profile/report/wearable-reusable plus a manual assessment-form overlay for symptoms/cardiac tests), calls `heart_risk_api`, stores an immutable `heart_risk_assessments` row. Synthetic-data model -- a screening signal, never a diagnosis |
| `routers/tracking.py`, `services/lifestyle_data.py`, `services/wearables.py` | Glucose, food (edits create revisions), lifestyle metrics, wearable connections and sync |
| `routers/care.py` | Side effects (with status history), doctor responses, appointment recommendations, visits, prescriptions |
| `routers/access.py` | Access requests (name + Patient ID must both match), approve, reject, revoke, doctor workspace, "My Day". The patient's QR code (`PatientQrCard`) encodes only name + Patient ID -- decoded entirely client-side by the doctor's scanner (`qr_scan_screen.dart`); it just pre-fills the same two fields this endpoint already requires, so no new endpoint or attack surface was added for scanning |
| `routers/follow_ups.py` | Follow-up tasks: create, list, complete, cancel, reschedule -- scheduling state, not append-only history |
| `routers/surgeries.py` | Surgery records; `internal_notes` is doctor/admin only, enforced by the serializer, never the client |
| `routers/ai.py`, `services/ai/` | Four separate AI services, staleness detection, stored summaries, PDFs |
| `routers/admin.py` | Doctors, patient accounts, write-only report upload, audit log, settings |
| `routers/notifications.py`, `services/records.py` | In-app notifications, preferences, device-token registration |
| `services/push.py` | Sends the system (FCM) half of every notification; a no-op until `FCM_SERVICE_ACCOUNT_JSON` is set |
| `services/reminders.py` | Background loop for food, lifestyle, follow-up and surgery reminders, deduplicated and respecting preferences |
| `services/pdf.py` | reportlab PDF of a stored AI summary, named `SUSTHITI_<Label>_<date>.pdf` |

### Security model

- **Authorization on every request.** A doctor's access is re-checked against an *approved* `AccessRequest`
  each time; revoking takes effect immediately. A doctor without approval gets 403 with a message asking the
  patient to approve access.
- **Admins read, never author, health data.** Admins open any doctor's or patient's profile (`routers/admin_profiles.py`)
  and read clinical records through the shared GET endpoints, which use `require_record_reader`. Every clinical
  write keeps its patient/doctor role gate, so admins cannot create or change records and authorship is preserved.
  Opening a patient profile writes a `patient_record_viewed` audit entry. Admins may correct a patient's name,
  phone and emergency contact (audited), and may upload a report on a patient's behalf (recorded as uploaded by
  the admin). This replaced the original "no clinical read" rule at the product owner's request (Sept 2026).
- **Append-only medical history.** Reports, assessments, prescriptions, visits and glucose readings are never
  updated in place. Food edits create a new revision and mark the old one superseded. Side-effect status
  changes are events.
- **Protected storage.** Uploaded files live outside any public directory under random references. The app
  fetches bytes through authorized endpoints; there are no public file URLs.
- **Secrets.** `JWT_SECRET` and `OPENROUTER_API_KEY` come from the environment. Production refuses to start with
  a weak JWT secret or with the development reset-token shortcut enabled.
- **Logging.** The request log records method, route template, status and duration. It never logs bodies,
  query strings, tokens, IDs or file contents.
- **Audit log.** Sign-ins, record creation, access decisions, AI generations, PDF downloads and admin actions
  are recorded with the actor and a non-sensitive label.

### Responsible AI and model use

- Model output is shown as "Model Classification Probability" and described as whether answers match a
  pattern associated with diabetes. It is never presented as a prediction of future onset.
- The heart risk screening is additionally labelled, everywhere it appears, as a synthetic-data research
  model (`susthiti-heart-v3`) -- never clinically validated, never a diagnosis, and never the same thing as
  the diabetes risk estimate. See `app/lib/data/models/heart_risk.dart`'s `HeartWording` for the single
  source of that wording in the app, and `services/ai/safety.py`'s `heart_screening_overclaim`/
  `diagnosis_certainty` checks for the backend enforcement.
- Each AI feature has its own system instruction and a structured JSON schema. Output is validated; invalid
  output returns `ai_invalid_response`, and the app offers Try Again while the original record stays visible.
- AI never prescribes, diagnoses with certainty or declares emergencies. Doctor responses to side effects are
  chosen by the doctor. The side-effect "priority" flag is a rule (patient-selected severe or emergency) and is
  labelled as not being a clinical judgement.

## Wearables

`WearableService` sits on a `WearableDataSource` interface. The backend knows three providers:
`health_connect`, `apple_health` and `demo`.

- The mobile build needs a platform plugin (for example `health`) that implements `WearableDataSource` for
  Health Connect and HealthKit. Until then the app shows those providers honestly as "not available here yet".
- The `demo` provider (enabled with `ENABLE_DEMO_WEARABLE=true`) generates samples that are stored with
  `is_demo=true` and always shown with a **DEMO** badge.
- The app never shows a metric the device did not provide, and it shows the last sync time and any sync failure.

## Key decisions

| Decision | Why |
| --- | --- |
| Each ML model behind its own service | Keeps scikit-learn and model versioning out of the API and lets a model be swapped only deliberately; the diabetes and heart services are independent processes with independent clients, so neither can affect the other |
| SQLite by default, SQLAlchemy throughout | Zero-setup local development; move to PostgreSQL with `DATABASE_URL` (see DATABASE.md) |
| Stored AI summaries | Viewing never regenerates; users regenerate explicitly. Summaries are marked stale when their source records change |
| No Alembic yet | Tables are created on startup. Add migrations before the first production schema change |

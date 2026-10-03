# SUSTHITI

Diabetes-focused longitudinal health monitoring for **patients**, **doctors** and **administrators**.

SUSTHITI keeps a patient's health history in one place: medical reports (original files are always kept),
diabetes assessments from the supplied model, glucose, food and lifestyle tracking, prescriptions, doctor
visits and side-effect reports. Doctors see a patient's records only after the patient approves them.
AI summaries (Google AI Studio) are generated on the backend, labelled as AI-generated, and never replace
the original records.

> SUSTHITI provides AI-assisted informational insights and does not replace professional medical
> diagnosis, treatment, or emergency care.

## Repository layout

| Folder | What it is |
| --- | --- |
| `app/` | Flutter app (Android, iOS, web, desktop). Riverpod, go_router, feature-based clean architecture. |
| `backend/` | FastAPI API: auth, role-based access, records, storage, notifications, AI and PDF generation. |
| `diabetes_risk_api/` | The supplied SUSTHITI Future Diabetes Risk API v4 (`unified_future_diabetes_model.joblib`), private behind the backend. See [docs/diabetes-api-v4-integration.md](docs/diabetes-api-v4-integration.md). |
| `diabetes_api/` | Superseded 16-question model service (kept for reference; not started). |
| `ml_service/` | Superseded placeholder (could not load the supplied artifact). Not used; safe to delete. |

Detailed guides:

- [PROJECT_EXPLANATION.md](PROJECT_EXPLANATION.md): what SUSTHITI is and the one rule everything else follows
- [ARCHITECTURE.md](ARCHITECTURE.md): how the pieces fit, security model, key decisions
- [API_SETUP.md](API_SETUP.md): running and configuring the backend, endpoint list
- [docs/diabetes-api-v4-integration.md](docs/diabetes-api-v4-integration.md): future diabetes risk (API v4): data sources, feature mapping, refresh policy
- [ML_MODEL_SETUP.md](ML_MODEL_SETUP.md): installing and verifying the supplied model
- [AI_SETUP.md](AI_SETUP.md): configuring Google AI Studio securely
- [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md): the AI pipeline, output safety validation, prompt versioning, caching, retry
- [DATABASE.md](DATABASE.md): data model and record-keeping rules
- [SECURITY.md](SECURITY.md): the security model end to end, and known gaps
- [TESTING.md](TESTING.md): running the test suites, what's covered
- [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md): index of env/setup docs, suggested CI
- [CHANGELOG.md](CHANGELOG.md): what's changed, in order

## Run everything (Windows)

Double-click **`start-susthiti.bat`** in the project folder (or run it from a terminal). It sets up anything missing,
starts the diabetes model service (port 8001), then the backend (port 8000), checks each one is healthy and connected,
and opens the app in Chrome (port 8080). Each service runs in its own "SUSTHITI" window; keep them open.

- Running the app from Android Studio instead: `start-susthiti.bat -App none`, then press Run in Android Studio.
- A phone on a USB cable (recommended for development): Android Studio run configuration **SUSTHITI phone (USB cable)**; after plugging a phone in later, run **`phone-usb.bat`**.
- A phone on the same Wi-Fi: `start-susthiti.bat -Lan`, then the **SUSTHITI phone (Wi-Fi)** run configuration. Run both again after the PC changes network.
- Stop everything: **`stop-susthiti.bat`**.
- Check the stack: http://127.0.0.1:8000/health should show `"model_service":"ok"`.

**Any phone, anywhere (no cable, PC off):** put SUSTHITI on an internet server with HTTPS — see **[DEPLOY.md](DEPLOY.md)**.

## Quick start (manual, any OS)

Requirements: Python 3.11+, Flutter 3.47+ (Dart 3.13+).

```bash
# 1. Backend
cd backend
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env            # then set JWT_SECRET; GEMINI_API_KEY is optional
python -m app.cli create-admin --email you@example.org --name "Your Name"   # prompts for a password
uvicorn app.main:app --reload --port 8000

# 2. Future Diabetes Risk API v4 (the supplied model, see docs/diabetes-api-v4-integration.md)
cd ../diabetes_risk_api
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 127.0.0.1 --port 8001

# 3. Flutter app
cd ../app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Optional DEMO accounts for local testing (refused when `SUSTHITI_ENV=production`):

```bash
cd backend && python -m app.cli seed-demo
# demo.patient@susthiti.test / demo.doctor@susthiti.test / demo.admin@susthiti.test, password Demo@12345
```

Demo accounts and demo wearable data are always labelled **DEMO** in the app. No health data is seeded.

## Roles

| Role | How the account is created | What they can do |
| --- | --- | --- |
| Patient | Self-registration in the app | Own records only; approve, reject or revoke doctor access |
| Doctor | Created by an Admin (no public sign-up) | Request access with patient name + Patient ID; read and add records only for approved patients |
| Admin | `python -m app.cli create-admin` (no public screen) | Manage doctors, patient accounts, access, audit log and settings; open any doctor or patient profile and **read** (never write) their complete record. Opening a patient profile is audited |

Roles are enforced in the backend on every request and mirrored in the app's routing.

## Tests and checks

```bash
cd backend && python -m pytest               # 83 API tests (access control, records, AI, diabetes risk, ...)
cd diabetes_risk_api && python -m pytest     # 13 contract tests against the real API v4 model
cd app && flutter analyze && flutter test && flutter build web
```

## Current status

- The supplied model runs in `diabetes_api/`. If that service is not running, the assessment screen says the
  service is temporarily unavailable and keeps the entered answers. No prediction is ever fabricated.
- AI features show "AI features are not set up on this server yet" until `OPENROUTER_API_KEY` is set on the backend.
- Android Health Connect and Apple Health are defined as integration points but need the platform
  plugins in the mobile build (see ARCHITECTURE.md). A clearly labelled DEMO device exists for development.

## Security notes

- No API keys in the Flutter app or in Git. The OpenRouter key lives only in the backend environment.
- `.env`, databases and uploaded files are git-ignored.
- Files are stored privately and served only through authorized endpoints, never as public URLs.
- Logs record the route template and status only: no bodies, tokens, IDs or medical content.

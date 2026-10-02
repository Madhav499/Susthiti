# Backend API setup

## Run locally

```bash
cd backend
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt          # add -r requirements-dev.txt for tests
cp .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"   # paste into JWT_SECRET in .env
uvicorn app.main:app --reload --port 8000
```

Interactive docs: `http://localhost:8000/docs`. Health check: `GET /health` returns `{"status":"ok","ai_configured":...}`.

### First admin

There is no public admin sign-up. Create the first administrator from the server:

```bash
python -m app.cli create-admin --email admin@yourclinic.org --name "Clinic Admin"
# prompts for the password, or reads SUSTHITI_ADMIN_PASSWORD
```

Admins then create doctor accounts in the app (Admin → Doctors → Add Doctor).

### Other CLI commands

| Command | Purpose |
| --- | --- |
| `python -m app.cli seed-demo` | Creates DEMO patient, doctor and admin accounts (development only; refused in production) |
| `python -m app.cli run-reminders` | Runs one reminder pass (useful from cron if the in-process loop is disabled) |

## Configuration (`backend/.env`)

| Variable | Default | Notes |
| --- | --- | --- |
| `SUSTHITI_ENV` | `development` | `production` enables strict checks |
| `DATABASE_URL` | `sqlite:///./susthiti.db` | Any SQLAlchemy URL, see DATABASE.md |
| `JWT_SECRET` | — | Required. Long random value. Production refuses weak values |
| `SESSION_HOURS` | `168` | Session lifetime |
| `STORAGE_DIR` | `./storage` | Private folder for uploaded files. Must not be web-served |
| `MAX_UPLOAD_MB` | `20` | Upload limit |
| `CORS_ORIGINS` | `http://localhost:5173,...` | Comma-separated origins allowed to call the API (the Flutter web origin) |
| `ML_SERVICE_URL` | `http://127.0.0.1:8001` | Diabetes model service |
| `ML_SERVICE_TIMEOUT_SECONDS` | `15` | |
| `GEMINI_API_KEY` | empty | Google AI Studio key. Empty disables AI features. See AI_SETUP.md |
| `GEMINI_MODEL` | `gemini-2.5-flash` | |
| `AI_TIMEOUT_SECONDS` | `90` | |
| `ENABLE_DEMO_WEARABLE` | `true` in example | Development-only DEMO device. Set `false` in production |
| `DEV_EXPOSE_RESET_TOKEN` | `true` in example | Returns the reset token in the response because no email provider is configured. Production refuses `true` |
| `REMINDERS_ENABLED`, `REMINDER_INTERVAL_MINUTES` | `true`, `60` | In-process reminder loop |

Never commit `.env`. In production, set these as environment variables or secrets in your hosting platform.

## Production checklist

- `SUSTHITI_ENV=production`, strong `JWT_SECRET`, `DEV_EXPOSE_RESET_TOKEN=false`, `ENABLE_DEMO_WEARABLE=false`.
- Serve over HTTPS behind a reverse proxy. Keep `STORAGE_DIR` on a private, backed-up volume.
- Use PostgreSQL and add migrations (DATABASE.md).
- Connect an email provider for password resets (the reset flow is in place; only delivery is missing).
- Restrict `CORS_ORIGINS` to the deployed web app origin.

## Flutter app configuration

The app has no secrets. Point it at the API at build time:

```bash
flutter run --dart-define=API_BASE_URL=https://api.yourclinic.org/api/v1
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=https://api.yourclinic.org/api/v1
```

`--no-web-resources-cdn` bundles the web engine with the app instead of loading it from Google's CDN.

## Error format

Every error has the same shape, which the app maps to typed failures:

```json
{"detail": {"code": "validation_error", "message": "Enter a valid phone number.", "details": {"field": "phone"}}}
```

Notable codes: `validation_error`, `not_found`, `authorization_error`, `conflict`, `model_service_unavailable`,
`ai_not_configured`, `ai_invalid_response`, `ai_service_unavailable`, `ai_timeout`.

## Endpoints (`/api/v1`)

| Area | Endpoints |
| --- | --- |
| Auth | `POST auth/register` (patients only), `POST auth/login`, `POST auth/logout`, `GET auth/me`, `POST auth/forgot-password`, `POST auth/reset-password`, `POST auth/change-password` |
| Patient profile | `GET/PATCH patients/me`, `PUT patients/me/photo`, `GET patients/{id}/profile`, `GET patients/{id}/photo`, `GET patients/{id}/dashboard`, `GET patients/{id}/trends`, `GET patients/{id}/timeline` |
| Reports | `GET/POST patients/{id}/reports`, `GET reports/{id}`, `GET reports/{id}/file` |
| Diabetes | `GET diabetes/features`, `GET/POST patients/{id}/assessments`, `GET assessments/{id}` |
| Tracking | `GET/POST patients/{id}/glucose`, `GET patients/{id}/glucose/overview`, `GET/POST patients/{id}/food`, `PUT food/{id}` (new revision), `GET food/{id}/history`, `POST patients/{id}/lifestyle`, `GET patients/{id}/lifestyle/overview` |
| Wearables | `GET wearables/providers`, `GET wearables`, `POST wearables/connect`, `POST wearables/{id}/sync`, `POST wearables/{id}/disconnect` |
| Care | `GET/POST patients/{id}/side-effects`, `GET side-effects/{id}`, `POST side-effects/{id}/responses`, `POST side-effects/{id}/status`, `GET/POST patients/{id}/appointment-recommendations`, `GET/POST patients/{id}/visits`, `GET visits/{id}`, `GET/POST patients/{id}/prescriptions`, `GET prescriptions/{id}` |
| Access | `GET/POST access-requests`, `POST access-requests/{id}/approve`, `.../reject`, `.../revoke`, `GET doctor/patients`, `GET doctor/dashboard` |
| AI | `GET/POST reports/{id}/summary`, `GET/POST patients/{id}/reports-summary`, `GET/POST patients/{id}/patient-summary`, `GET/POST patients/{id}/lifestyle-insight`, `POST assessments/{id}/interpretation`, `GET ai-summaries/{id}/pdf` |
| Notifications | `GET notifications`, `GET notifications/unread-count`, `POST notifications/{id}/read`, `POST notifications/read-all`, `GET/PUT notifications/preferences` |
| Admin | `GET admin/dashboard`, `GET/POST admin/doctors`, `PATCH admin/doctors/{id}`, `GET admin/patients`, `POST admin/patients/{id}/status`, `POST admin/patients/{id}/reports` (write-only), `GET admin/audit-logs`, `GET/PUT admin/settings` |

## Tests

```bash
cd backend && pip install -r requirements-dev.txt && python -m pytest
```

The tests use a temporary SQLite database, a fake ML service and a fake Gemini client, so no network or keys are needed.

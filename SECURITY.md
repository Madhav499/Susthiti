# Security

What's actually enforced, where, and what's still on you. For the AI-specific safety layer
(output validation, allergy/restriction conflicts, prompt injection posture) see
[AI_ARCHITECTURE.md](AI_ARCHITECTURE.md); for the deployment-time checklist see
[DEPLOY.md](DEPLOY.md).

## Authentication and sessions

- Passwords are bcrypt-hashed (`backend/app/security.py`). Access tokens are JWTs, but the
  authority is the database: each JWT's `jti` names an `auth_sessions` row, and
  `get_current_user` (`backend/app/deps.py`) checks that row is not revoked and not expired on
  every request, plus that the user is still `is_active`. Revoking a session (logout) takes
  effect immediately — the JWT alone is never enough to stay signed in.
- Password reset tokens are one-time, hashed (`password_reset_tokens.token_hash`, SHA-256) —
  the raw token is never stored.

## Authorization

- Every patient-scoped endpoint goes through `authorize_patient()` (`backend/app/deps.py`):
  a patient may only ever touch their own records; a doctor only with an **approved**
  `access_requests` row, re-checked on every single request (revoking is immediate); an admin
  reads any patient but never writes clinical data, because every write endpoint's role
  dependency (`require_clinical`, `require_patient`, `require_doctor`) excludes `admin` at the
  routing layer — admin can't reach a write handler at all, not just "shouldn't."
- This is enforced in the backend, not the Flutter app. `app/lib/core/routing/app_router.dart`'s
  `roleRedirect` exists only to keep a user out of a screen they could never load anyway; a
  malicious client that skips the UI and calls the API directly gets the exact same 403s.
- A doctor requesting access must supply the patient's name **and** patient code together, so a
  doctor can't enumerate patients by code alone.
- **Patient QR identity code.** The QR SUSTHITI shows the patient (`PatientQrCard`) encodes
  only their name and opaque Patient ID -- nothing medical. Scanning it (`qr_scan_screen.dart`)
  decodes those two fields **entirely on the device**; there is no server lookup-by-code
  endpoint, so scanning adds no way to resolve a code to a name beyond what the manual form
  already requires, and no new enumeration surface. The access-request's existing name+code
  match check is the only authority either way.

## Rate limiting

`backend/app/services/rate_limit.py`: an in-memory, per-client-IP sliding window on login (20/5
min), registration (20/hour) and password reset (10/hour). `AUTH_RATE_LIMIT_ENABLED=false` in
production is a hard startup failure (`backend/app/config.py`). Behind a reverse proxy the real
client address only arrives via `X-Forwarded-For`, so uvicorn must run with `--proxy-headers`
(the Docker image already does).

## Production safety gate

`get_settings()` (`backend/app/config.py`) refuses to start in `SUSTHITI_ENV=production` if:
the JWT secret is the dev default or under 32 characters; `DEV_EXPOSE_RESET_TOKEN=true`;
`ENABLE_DEMO_WEARABLE=true`; or rate limiting is disabled. A misconfigured production deploy
fails loudly at boot instead of running insecurely.

## Storage

`backend/app/services/storage.py`: uploaded reports and profile photos are written under
`STORAGE_DIR` with random opaque filenames (`secrets.token_hex(16)`), `chmod 0o600`. There is no
public path to a file — every read goes through an authorized API endpoint
(`GET /reports/{id}/file`). Swapping to a cloud bucket means implementing the same `save`/`read`
interface with a private bucket; nothing in the routers needs to change.

## AI output safety validation

Prompt instructions alone are not a safety boundary — they're a request, not a guarantee. A
deterministic second check (`backend/app/services/ai/safety.py`) runs on every AI result after
schema validation and before storage, and discards anything that matches a forbidden pattern
(medication/supplement dosage, emergency declarations, numeric targets, future-onset
probability claims, uncertain-advice-field diagnosis language, or a suggestion that conflicts
with a documented allergy/restriction). See [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md) for the
full pipeline and category list.

## Logging and audit

- Request logs (`backend/app/main.py`) record method, route template, status and duration only
  — never bodies, query strings, tokens or IDs.
- `audit_logs` (`backend/app/services/records.py`'s `audit()`) records who did what to which
  entity with a non-sensitive label — sign-ins, record creation, access decisions, AI
  generations (including safety-validation rejections, by reason code only, never the rejected
  content), PDF downloads, admin actions.

## Known gaps (not yet done; tracked, not hidden)

- **Password-reset email delivery.** The reset flow works end-to-end except actually sending the
  email — no SMTP/email provider is wired up yet. `DEV_EXPOSE_RESET_TOKEN` is a development-only
  stand-in and is refused in production.
- **Android release signing.** `app/android/app/build.gradle.kts` currently signs release builds
  with the debug key. Fine for internal testing and sideloading; needs a real release key before
  any Play Store distribution.
- **No CI.** There is no automated pipeline running `pytest`/`flutter analyze`/`flutter test` on
  every change yet (see [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) for a starting point).
- **No Firestore/Firebase App Check equivalent.** Not applicable — this backend is FastAPI, not
  Firebase. Authorization is enforced in `deps.py` on every request instead.

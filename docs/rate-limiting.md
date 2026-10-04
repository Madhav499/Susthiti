# Rate limiting

SUSTHITI throttles two different kinds of endpoint, both through one in-memory limiter
(`backend/app/services/rate_limit.py`) and one feature flag (`AUTH_RATE_LIMIT_ENABLED`, required
`true` in production):

1. **Public sign-in endpoints** — `limit(bucket, attempts, per_seconds)`, counted per **client
   IP**. Protects against password guessing and registration/reset abuse before anyone is signed
   in, so there's no account identity to key on yet.
2. **Authenticated endpoints that call a metered external service** — `limit_by_user(bucket,
   attempts, per_seconds)`, counted per **signed-in user id** (`current.id`, from the verified
   JWT via the same `get_current_user` dependency every authorization check in this codebase
   already goes through). Never keyed by a client-supplied `patient_id`/`doctor_id`, and never by
   IP alone — IP-only limiting both over-blocks many users sharing one network and under-limits
   one user who simply switches networks.

Both call the same `RateLimiter` (a sliding window over a `deque` per key) and raise the same
`errors.too_many_attempts()` — an `HTTP 429` with `detail.code == "rate_limited"`, a generic
message, and a `Retry-After` header set to the exact number of seconds until the window clears.
No internal detail (which bucket, how the key was built, the limiter's internal state) is ever
exposed in the response.

## Why user-id, not IP, for these endpoints

Every endpoint `limit_by_user` protects already requires sign-in. Keying on the authenticated
user id (not the request's IP) means:

- One account can't be starved by another account sharing its network (mobile carrier NAT, campus
  Wi-Fi, a shared clinic connection).
- One account can't inflate its own quota by switching networks.
- The limit tracks the thing actually being protected — the account that will trigger the
  OpenRouter/ML-service spend — not an incidental network detail.

## Endpoints protected and exact limits

| Bucket | Endpoints | Limit | Window | Why this number |
|---|---|---|---|---|
| `ai-generate` | `POST /reports/{id}/summary`, `POST /patients/{id}/reports-summary`, `POST /patients/{id}/patient-summary`, `POST /patients/{id}/friendly-summary`, `POST /patients/{id}/lifestyle-insight`, `POST /assessments/{id}/interpretation`, `POST /heart-risk/{id}/interpretation` | 10 requests | 10 minutes | All seven call the same metered OpenRouter budget, so one shared per-user budget is what actually matters — not seven independent ones. 10 per 10 minutes comfortably covers a real session (reviewing several reports, generating a patient summary, a lifestyle insight, maybe a force-regeneration) while still being a real brake on a scripted loop: at most 60 AI calls/hour/account instead of unlimited. |
| `diabetes-risk-predict` | `POST /patients/{id}/diabetes-risk` | 6 requests | 10 minutes | A refresh is normally rare — triggered by new data arriving, or a patient/doctor correcting an input and resubmitting once or twice. 6 per 10 minutes is generous for that and a real cap against a loop against the metered ML service. |
| `heart-risk-predict` | `POST /patients/{id}/heart-risk` | 6 requests | 10 minutes | Mirrors `diabetes-risk-predict`. Kept as its own bucket — not shared with diabetes risk — so heavy legitimate use of one screening feature never eats into the other's budget. |

`GET` endpoints (reading an existing summary/assessment, downloading a generated PDF) are **not**
rate-limited — they never call the AI provider or an ML service, and limiting them would only
risk blocking normal use (e.g. a doctor scrolling through several patients' already-generated
summaries) for no abuse-protection benefit.

The existing auth-endpoint limits (`register`, `login`, `password-reset`) are unchanged by this
work — see `backend/app/routers/auth.py`.

## What's deliberately out of scope here

`POST /access-requests` (doctor creates an access request) was flagged in the security audit as
also worth rate-limiting (notification-spam potential, not cost), but is a separate finding from
"AI-summary and risk-prediction endpoints can run up metered costs" and is intentionally not
touched by this change.

## Multi-instance limitation (read before scaling horizontally)

The limiter is in-memory and per-process. On Render's current single-instance deployment this is
correct and sufficient. If this backend is ever scaled to more than one instance, **each instance
keeps its own counters** — a user's requests get spread across instances (depending on Render's
load balancing), so the *effective* limit becomes `limit × instance count`, not the documented
limit. This is a real, known limitation, not a bug.

This is **not** being fixed by introducing Redis or any other shared store: SUSTHITI has no other
dependency on shared infrastructure today, and adding one solely for this would be a bigger
architectural change than the finding warrants for a single-instance deployment. If/when the
backend genuinely needs more than one instance, revisit this limiter first — either move the
counters to Postgres (already a dependency) or introduce a shared cache at that point, deliberately,
rather than as a side effect of a rate-limiting patch.

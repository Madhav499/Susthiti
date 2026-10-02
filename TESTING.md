# Testing

## Backend

```bash
cd backend
pip install -r requirements-dev.txt
python -m pytest
```

116 tests across `backend/tests/`: `test_api.py` (auth, roles, access control, reports,
prescriptions, AI, admin), `test_diabetes_risk.py` (future diabetes risk API v4 integration),
`test_patient_experience.py` (timeline, BMI, birthdays, reassessment lifecycle),
`test_report_reading.py` (automatic HbA1c/glucose extraction from reports),
`test_security_limits.py` (rate limiting, production-settings refusal), `test_ai_safety.py`
(output safety validation), `test_ai_caching.py` (regeneration reuse/force), `test_ai_retry.py`
(bounded retry/backoff).

No network or real keys are needed: `backend/tests/conftest.py`'s `env` fixture gives every test
a fresh temporary SQLite database plus two test doubles wired in as the real clients:

- `FakeRiskAPI` — an `httpx.MockTransport` handler that follows the real Diabetes Risk API v4's
  contract (health check, categorical validation, risk bands, BMI calculation), with a
  `respond_with`/`fail` toggle for forcing other failure modes.
- `FakeGemini` — the same kind of double for Google AI Studio. `queue_json(obj)` queues a
  successful JSON response; `queue_raw(response)` queues an arbitrary `httpx.Response` (used for
  malformed/error/retry tests). `gemini.requests` captures every call made, so a test can assert
  the AI either was or wasn't called.

Tests that exercise `GeminiClient`'s retry/backoff monkeypatch `time.sleep` in
`app.services.ai.gemini` so they run in milliseconds instead of real backoff delays — see
`test_ai_retry.py` for the pattern; reuse it rather than letting a new retry-path test actually
sleep.

**Windows note:** if `pytest` fails to import with `ImportError: DLL load failed... An
Application Control policy has blocked this file`, that's Windows Smart App Control (or a
similar endpoint-security policy) blocking SQLAlchemy 2.1's new Cython accelerator modules, not
a code defect. `backend/requirements.txt` already pins `sqlalchemy>=2.0,<2.1` for this reason —
if you see this on a 2.1+ install, reinstall with that pin. The same policy also blocks
Flutter's own `flutter_tester.exe`, so on an affected machine `flutter test` cannot run at all
(static analysis via `flutter analyze` is unaffected, since it never executes a native binary).
This is a machine security policy, not something either project's code can work around.

## Flutter

```bash
cd app
flutter analyze
flutter test
```

15 widget/unit test files under `app/test/`, including `widget/ai_summary_section_test.dart`
(asserts the "AI" badge and disclaimer are visible, the stale banner appears, admins can view
but never generate/regenerate) and `unit/role_redirect_test.dart` (the client-side route-gating
logic, which mirrors but does not replace the backend's own authorization checks).

## What's covered vs. not yet

Covered: valid/malformed/missing-field AI JSON, AI timeout and 429/500 retry paths, medication/
supplement/emergency/numeric-target/future-onset/diagnosis-certainty/allergy-conflict safety
rejections (one test per category plus two false-positive guards), AI regeneration caching and
`force`, duplicate-prescription rejection, doctor-only vs patient-writable health-profile
fields, role-based access control (patient-own-data-only, doctor-approved-access-only,
admin-read-only), rate limiting, production-settings refusal.

Not yet covered: a live integration test against the real Gemini API (all AI tests use
`FakeGemini`, by design — no key or network needed to run the suite); Firestore/Storage
security rules (not applicable — there is no Firestore in this project); a full cross-device UI
pass (manual, see the smoke-test steps in the root `README.md`).

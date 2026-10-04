# Changelog

Dates are when the work was done in this engagement, not a release schedule.

## 2026-10-04 — Heart disease risk screening, patient QR identity

Additive throughout: every existing diabetes/AI/notification/access-request behavior keeps
working unchanged. Full detail in [ML_MODEL_SETUP.md](ML_MODEL_SETUP.md),
[AI_ARCHITECTURE.md](AI_ARCHITECTURE.md), [DATABASE.md](DATABASE.md) and
[ARCHITECTURE.md](ARCHITECTURE.md); this is the shipped-in-order summary.

- **New ML service `heart_risk_api/`** (port 8002): the supplied model `susthiti-heart-v3`
  (Extra Trees, 600 trees, Platt-calibrated, threshold 0.3275, trained on a **20,000-row
  SYNTHETIC dataset**), deployed verbatim -- no retraining, no threshold change. Mirrors
  `diabetes_risk_api`'s packaging exactly.
- **New backend package `services/heart_risk/`** (client, feature builder, coordinator,
  presentation) and table `heart_risk_assessments` -- sibling to `services/diabetes_risk/`,
  independent, immutable, full provenance per assessment, never overwritten. New router
  `routers/heart_risk.py` (`GET`/`POST /patients/{id}/heart-risk`, `.../history`,
  `GET /heart-risk/{id}`), reusing the same `authorize_patient`/`require_clinical` deps as
  diabetes. Also wired into the existing patient dashboard, timeline and admin patient-profile
  endpoints alongside diabetes, unchanged.
- **Data reuse, not re-asking**: 7 new report-value analytes (total/LDL/HDL cholesterol,
  triglycerides, troponin, hemoglobin, creatinine) and 5 new health-profile fields (family
  history of heart disease, previous heart disease/attack, kidney disease, stroke), both
  reusable generically by the existing report-confirmation and health-profile UI. Vitals
  (heart rate, SpO2, blood pressure) reused from the existing wearable/lifestyle data. Symptom
  and cardiac-test fields are always answered fresh on the assessment form, never prefilled,
  never inferred.
- **AI summaries are heart-aware**: `PatientSummaryService`, `PatientFriendlySummaryService`
  and `LifestyleAIService` (patient summary, your-health summary, lifestyle insight, and a new
  `interpret_heart_assessment()` parallel to the existing diabetes interpretation) now receive
  structured heart screening data and are explicitly instructed never to call it a diagnosis,
  never claim it's clinically validated, and never conflate it with the diabetes estimate.
  `services/ai/safety.py` gained matching deterministic checks. Diabetes AI behavior and
  prompts are otherwise untouched (new prompt versions were bumped where the shared instruction
  text changed, so stale cached summaries regenerate once).
- **Flutter**: Diabetes and Heart are now two tabs of one swipeable page (same `TabBarView`
  construction the doctor/admin patient-detail screens already use for their own tabs), plus a
  7-section assessment form, result/history/detail screens, all under `features/heart/` and
  `data/models/heart_risk.dart` -- sibling to the diabetes feature, not a modification of it.
- **Patient QR identity**: `PatientQrCard` on the profile screen encodes only the patient's
  name and opaque Patient ID -- the same two fields a doctor already has to type into the
  existing manual "Request Access" form. The doctor's new scanner
  (`features/doctor/qr_scan_screen.dart`, reached from the Patients list and from "Add
  Patient") decodes it **entirely client-side** and hands the two fields to the exact same
  `POST /access-requests` call the manual form uses -- no new backend endpoint, no lookup-by-
  code, no new enumeration surface. Manual entry is untouched and still the primary flow.
- **Wording fix**: the doctor's submit button read "Send access request"; renamed to
  "Request Access" (a doctor requests access, they don't send a request).
- Three real bugs caught and fixed during implementation before they shipped: a `sex`
  vocabulary case mismatch and a troponin-precision rounding bug in the new heart feature
  mapping (both silently dropped/zeroed real values), and a latent `AddDataTarget`/
  `stress_level` gap that would have mis-routed a missing-data link or silently failed to
  reuse an incompatible profile field.

## 2026-10-02 — Spec-alignment hardening

Starting point: an audit found SUSTHITI already had a mature, working architecture (Flutter +
FastAPI + SQLAlchemy/SQLite + custom JWT auth + Google Gemini) that satisfied most of a
60-section specification's underlying principles, just via different technology than the
spec assumed (it was written for Firebase + OpenRouter). Decision: keep the existing stack,
apply the spec's principles to it. Full audit findings and the staged plan are not duplicated
here; this lists what actually shipped, in order.

- **Git safety net.** This repository had no version control at all before this work. Added
  `.gitignore` coverage for packaged build/deploy artifacts (`release/`, `deploy/web/*`) and
  made the first commit.
- **Fixed the local backend test environment.** `backend/requirements.txt` now pins
  `sqlalchemy>=2.0,<2.1` — 2.1's new Cython accelerator modules were being blocked by Windows
  Smart App Control on the development machine (`An Application Control policy has blocked this
  file`), which is a machine security policy, not a code defect. See
  [TESTING.md](TESTING.md).
- **Allergies and doctor restrictions as authoritative data.** Reused the existing flexible
  `HealthFact` profile model (no new table) to add `allergies` (patient- or doctor-writable) and
  `doctor_restrictions` (doctor-only, enforced server-side). Both now feed Lifestyle AI's
  context and its system instructions.
- **Deterministic AI output safety validation layer.** New
  `backend/app/services/ai/safety.py`, run after schema validation and before any AI result is
  stored, on every one of the 4 AI services' output. See [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md)
  for the full category list. Nothing unsafe is ever stored or shown; the app's existing
  "Try Again, your data is safe" UI handles the rejection with no frontend changes needed.
- **AI prompt/schema versioning.** Every `AISummary` now records which prompt version produced
  it; a later prompt change marks old summaries as refreshable without deleting their history.
- **AI regeneration caching.** Each AI endpoint skips calling Gemini again when the source data
  and prompt version are unchanged since the last generation (mirroring the existing
  diabetes-risk refresh pattern), with an explicit `force` parameter for a genuine regenerate.
- **Bounded retry with backoff for transient AI failures.** 429/500/502/503/504 responses from
  Gemini are retried up to 3 times with backoff (honoring `Retry-After` when sent), bounded by
  the existing `AI_TIMEOUT_SECONDS` budget rather than multiplying it.
- **Duplicate-prescription guard.** A doctor double-submitting the exact same prescription
  (same patient, doctor, date, medicines) is now rejected with a 409 instead of silently creating
  a second identical record.
- **AI labeling audit.** Confirmed every AI-bearing screen, including assessment interpretation,
  already renders through the shared `AiSummarySection` widget — the "AI-generated" badge and
  disclaimer were already applied consistently; no gap found, no change needed.
- **Documentation.** Added this file, [SECURITY.md](SECURITY.md),
  [TESTING.md](TESTING.md), [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md),
  [PROJECT_EXPLANATION.md](PROJECT_EXPLANATION.md), [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md).

**Explicitly scoped out, by the user's choice, not an oversight:** an opt-in flag letting a
doctor hide a visit note from the patient it's about. The product has no such concept anywhere
today (patients already see all their own clinical records; admins are read-only), so adding it
would have been a product-policy change, not hardening — skipped after checking rather than
built unilaterally.

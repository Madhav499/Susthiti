# Changelog

Dates are when the work was done in this engagement, not a release schedule.

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

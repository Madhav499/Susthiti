# AI architecture

For configuring the Gemini key itself, see [AI_SETUP.md](AI_SETUP.md). This document is about
the pipeline the key feeds into: what gets sent, what comes back, and what happens to it before
a patient or doctor ever sees it.

## Provider

OpenRouter (`backend/app/services/ai/openrouter.py`), called over HTTPS from the backend — no
SDK, no direct provider calls. The key (`OPENROUTER_API_KEY`) lives only in backend environment
config. The Flutter app never holds a key and never calls OpenRouter directly; it calls the
SUSTHITI backend, which calls OpenRouter.

## The four services

One module (`backend/app/services/ai/services.py`), one class per question, each with its own
system instruction and JSON output schema (`backend/app/services/ai/schemas.py`):

| Service | Question | Prompt version | AISummary kind |
| --- | --- | --- | --- |
| `ReportSummaryService` | What does this one report say? | `report-summary-v1` | `individual_report` |
| `AllReportsSummaryService` | What do the reports show over time? | `all-reports-summary-v1` | `all_reports` |
| `PatientSummaryService` | What is this patient's longitudinal history? | `patient-summary-v1` | `patient_summary` |
| `LifestyleAIService.suggest()` | What lifestyle changes might help? | `lifestyle-v1` | `lifestyle` |
| `LifestyleAIService.interpret_assessment()` | How does a symptom-model result relate to recent lifestyle? | `assessment-interpretation-v1` | `assessment_interpretation` |
| `LifestyleAIService.interpret_heart_assessment()` | How does a heart risk *screening* result relate to recent lifestyle? | `heart-assessment-interpretation-v1` | `heart_interpretation` |

A fifth, narrower service, `LabValuesExtractionService` (`lab-values-extraction-v1`), only
copies HbA1c/glucose values verbatim from a scanned report image — it never interprets, and its
output is never stored as an `AISummary`; it feeds the report-value confirmation workflow
instead (`backend/app/services/health_data/report_extraction.py`).

Every system instruction shares one `_SAFETY` clause (`services.py`): never diagnose with
certainty, never prescribe or change medication/dosage, never declare an emergency, never
predict a timeframe or probability of developing diabetes **or heart disease**, never tell the
patient to ignore their doctor, and always say "not available" rather than guessing. `_SAFETY`
also states explicitly that the heart risk screening (model `susthiti-heart-v3`, trained on
synthetic data) is a screening signal, never a diagnosis, never clinically validated, and never
to be treated as equivalent to the separate diabetes risk estimate. The two `LifestyleAIService`
instructions additionally tell the model that supplied allergies and doctor-recorded
restrictions are authoritative and must never be contradicted by a suggestion.

## Request pipeline

```
Flutter (authenticated request)
  -> FastAPI route: require_clinical / require_record_reader
  -> authorize_patient() -- the same check on every request, not cached
  -> build structured context from the database (the backend computes trends/overviews;
     see lifestyle_data.py -- the AI explains verified numbers, it never computes them)
  -> cache check: does a stored summary already match this fingerprint + prompt version?
       yes, and not force=true -> return it, no AI call (see "Caching" below)
       no, or force=true -> continue
  -> GeminiClient.generate_json(): bounded retry with backoff on 429/500/502/503/504 (see
     "Retry and rate limits" below), schema validation (pydantic, "lenient" -- unknown
     fields ignored, missing required fields reject the whole response)
  -> safety.check_output(): deterministic pattern checks (see "Output safety validation")
  -> store as a new AISummary row (regenerating never overwrites; old versions are kept)
  -> return the validated, stored result to Flutter
```

Nothing in this chain lets the AI write back into a source table (`reports`, `report_values`,
`health_facts`, `prescriptions`, ...). An `AISummary` is always a new, separate row; the facts it
was built from are never touched.

## Output safety validation

`backend/app/services/ai/safety.py`'s `check_output(kind, content, context)` runs after schema
validation, before storage. It is deterministic (regex/keyword), not a second AI call —
consistent with the rest of the codebase's philosophy that the backend computes and verifies,
and AI only narrates (the same reasoning behind `lifestyle_data.py` computing trends instead of
asking the model to). A second AI "judge" would add latency, cost, and a non-deterministic gate
for exactly the layer that most needs to be deterministic and auditable.

Categories checked, with scope:

| Category | Scope | Catches |
| --- | --- | --- |
| `medication_dosage` | every string field | "take 500mg", "increase your dose", "stop/start taking" |
| `supplement_dosage` | every string field | "take 1000 IU of...", "2 tablets of..." |
| `emergency_declaration` | every string field | "this is an emergency", "go to the ER", "call 911" |
| `numeric_target` | every string field | "walk exactly 8000 steps", "drink 2L of water", "eat 1800 calories" |
| `future_onset_claim` | every string field | "will develop diabetes", "80% chance of developing..." |
| `diagnosis_certainty` | advice fields only (`interpretation`, `suggestions`, `observations`, `contributing_patterns`, `questions_for_doctor`) | "you have diabetes", "you have heart disease", "this confirms you...", "heart disease is confirmed" |
| `heart_screening_overclaim` | advice fields only | "clinically validated", "confirmed/definite/certain diagnosis" — guards the synthetic heart model specifically |
| `allergy_or_restriction_conflict` | advice fields only | a suggestion naming a documented allergen/restriction without a negation nearby |

`diagnosis_certainty` is deliberately scoped to the AI's own advice-voice fields, not to fields
meant to recite documented history (e.g. `diabetes_history`, `medical_reports`) — a `Patient
Summary` narrating "diagnosed with hypertension on a past visit" is reciting a real record, not
the AI diagnosing anyone, and scoping the check this way avoids flagging that.

`allergy_or_restriction_conflict` only triggers when `context` carries `allergies` /
`doctor_restrictions` (currently: `LifestyleAIService` calls only). Matching is a simple
stopword-filtered keyword/stem substring check with a "is there a negation word nearby" guard —
not synonym expansion. A restriction phrased as "avoid peanuts" and a suggestion that actually
avoids peanuts will not be flagged; a suggestion that names the allergen without a nearby
negation will be. This is a known, intentional v1 limitation, not full NLP.

On any violation: nothing is stored, the request fails with the same `ai_invalid_response`
(502) the app already has a full UI for ("We couldn't generate the summary right now, your
original data is safe, Try Again" — `app/lib/features/ai/ai_summary_section.dart`), and an
`ai_safety_violation` audit entry records the category codes that fired — never the rejected
text itself.

## Prompt/schema versioning

Every `AISummary` stores `prompt_version` (e.g. `"lifestyle-v1"`). When a service's constant is
bumped (a real prompt or schema change), every stored summary from the old version is treated as
stale on its next GET, alongside the existing data-fingerprint staleness check — so a prompt
improvement surfaces as "this may be out of date, regenerate" rather than silently leaving old
summaries looking current, and without deleting history.

## Caching

Regenerating is not free, and the backend already knows whether anything changed:
`routers/ai.py`'s `_reusable()` checks the latest stored summary's `source_fingerprint` and
`prompt_version` against what a fresh generation would use. If both match and the caller didn't
pass `force=true`, the existing summary is returned (HTTP 200, `"created": false`) and Gemini is
never called. An explicit regenerate passes `force=true` and always calls the AI, same as a
genuine data change always does regardless of `force`.

## Retry and rate limits

`GeminiClient.generate_json` retries up to 3 attempts on `429/500/502/503/504`, honoring
`Retry-After` when Gemini sends one, falling back to exponential backoff (1s, 2s) otherwise. The
whole attempt — every retry and sleep — stays inside the existing `AI_TIMEOUT_SECONDS` budget; it
is never multiplied out. A non-retryable status, or an exhausted budget, fails immediately with
the existing `ai_service_unavailable` (503) / `ai_timeout` (504) codes the app already handles.

## What the AI never sees or does

- No AI call ever receives raw patient-entered free text without it being wrapped in the
  structured JSON context sent alongside explicit system instructions — there is no
  dedicated prompt-injection sanitizer beyond that structuring plus the output-side safety
  checks above; treat this as defense-in-depth, not a guarantee, same as any LLM-backed feature.
- The AI never computes a numeric trend, a health score, or a risk percentage. Those come from
  stored, backend-computed values (`lifestyle_data.py`, `diabetes_risk/coordinator.py`,
  `heart_risk/coordinator.py`); the AI explains a number it was handed, it does not produce one.
- The AI never changes a `report_values`, `health_facts`, `prescriptions`, or `visits` row.
- The AI never turns the heart risk screening's model score into a confirmed diagnosis, never
  states the synthetic-data model is clinically validated, and never merges it with the
  diabetes risk estimate as if they measured the same thing — see `heart_risk_assessments` /
  `latest_heart_risk_screening` in the structured context passed to `PatientSummaryService`,
  `PatientFriendlySummaryService` and `LifestyleAIService` (`routers/ai.py`).

# What SUSTHITI is

SUSTHITI is a diabetes-focused longitudinal health record. A patient's reports, assessments,
glucose readings, food log, lifestyle data, prescriptions, doctor visits and side-effect reports
all live in one place, kept over time. Doctors see a patient's records only after that patient
explicitly approves their access, and can revoke it at any point. AI (Google AI Studio) adds an
informational interpretation layer on top of that record — always labelled as AI-generated,
never a replacement for it.

> SUSTHITI provides AI-assisted informational insights and does not replace professional
> medical diagnosis, treatment, or emergency care.

For how the pieces fit together technically, see [ARCHITECTURE.md](ARCHITECTURE.md). For the
data model, see [DATABASE.md](DATABASE.md). For the AI pipeline specifically, see
[AI_ARCHITECTURE.md](AI_ARCHITECTURE.md).

## The one rule everything else follows

**The database is the source of truth. AI explains it; AI never becomes it.**

Concretely, this shows up as:

- **Append-only medical history.** A report, an assessment, a glucose reading, a prescription,
  a visit — none of these are ever edited or deleted. A correction creates a new row that
  references the one it supersedes (see `DATABASE.md`'s "Record-keeping rules"). The full history
  is always still there.
- **AI output is always a new, separate row.** `ai_summaries` rows are never overwritten by a
  regeneration; the old one stays, the new one is added. An `AISummary` can be discarded and
  regenerated endlessly without ever touching the clinical data it was built from.
- **Numbers are computed by the backend, not guessed by the AI.** A lifestyle trend, a glucose
  weekly average, a risk percentage — these are calculated once in Python from stored values
  (`backend/app/services/lifestyle_data.py`, `services/diabetes_risk/`) and handed to the AI as
  already-verified facts. The AI explains a number; it does not invent one.
- **A deterministic safety check, not just a prompt instruction, gates AI output.** Every AI
  service is told not to prescribe, diagnose with certainty, declare an emergency, or predict a
  timeframe for developing diabetes — but that's a request, not a guarantee. A second,
  code-level check (`backend/app/services/ai/safety.py`) actually verifies the response doesn't
  do any of those things before it's ever stored or shown. See `AI_ARCHITECTURE.md` for the full
  list of what it catches.

## Roles

| Role | Created by | Can do |
| --- | --- | --- |
| Patient | Self-registration | Own records only; approve, reject or revoke a doctor's access |
| Doctor | An admin (no public sign-up) | Request access by name + patient code; read and add records only for patients who approved them |
| Admin | `python -m app.cli create-admin` | Manage doctors, patient accounts, access relationships, audit log, settings — reads any record for support/oversight, but can never author or edit one |

Every one of these boundaries is enforced in the backend on every request
(`backend/app/deps.py`'s `authorize_patient`), not just hidden in the Flutter UI — a client that
bypasses the app entirely and calls the API directly gets exactly the same restrictions.

## What SUSTHITI deliberately does not do

- It does not diagnose. A diabetes-risk percentage is a screening estimate from a supplied
  model, explicitly worded as a classification of symptom/data patterns, never a diagnosis or a
  prediction of if/when someone will develop diabetes.
- It does not prescribe or adjust medication. Prescriptions are created by a doctor through a
  structured form; the AI cannot write to that table, and is explicitly instructed and then
  code-checked never to suggest a dose, a supplement amount, or a medication change.
- It does not declare emergencies. A severe/emergency side-effect report sets a rule-based
  priority flag (patient-selected severity, not a clinical judgement) for a doctor to act on; the
  AI is checked to never tell a patient this is an emergency itself.

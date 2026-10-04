# Database

SQLAlchemy 2 models live in `backend/app/models.py`. SQLite is the default for local development. Tables are
created on startup (`init_db`).

## Using PostgreSQL

```bash
pip install "psycopg[binary]>=3.2"
DATABASE_URL=postgresql+psycopg://susthiti:<password>@db-host:5432/susthiti
```

Before the first production schema change, add Alembic migrations (`alembic init`, then autogenerate from
`app.db.Base.metadata`). Until then, schema changes need a manual migration.

## Record-keeping rules

- **Medical history is never overwritten.** Reports, assessments, glucose readings, prescriptions, visits,
  appointment recommendations and AI summaries are insert-only. There are no update or delete endpoints for them.
- **Food edits create a revision.** `PUT /food/{id}` inserts a new `food_entries` row with `previous_id` pointing
  to the old one and sets the old row's `superseded_at`. Lists show the current revision; history is available.
- **Side-effect progress is an event log.** Every status change and doctor response is a `side_effect_events` row.
- **Medical date vs upload date.** Reports keep `report_date` (when the test was done) separately from
  `uploaded_at`. Timelines and AI trend analysis order by the medical date.
- **Uploader attribution.** Reports store the uploader's role, user ID and name. Prescriptions, visits and AI
  summaries store who created them.
- **DEMO data.** `users.is_demo`, `glucose_readings.is_demo`, `lifestyle_metrics.is_demo` and
  `wearable_connections.is_demo` mark demonstration data, which the app always labels DEMO.
- **Human-readable codes** come from the `counters` table: `SUS-P-XXXXXX` (patients), `SUS-D-XXXXXX` (doctors),
  and sequential codes for reports, assessments, prescriptions, visits and side effects.

## Tables

| Table | Purpose | Notable columns |
| --- | --- | --- |
| `users` | Accounts for all roles | `email` (unique), `password_hash` (bcrypt), `role`, `is_active`, `is_demo`, `last_login_at` |
| `auth_sessions` | Revocable sessions behind each JWT | `expires_at`, `revoked_at` |
| `password_reset_tokens` | One-time reset tokens | `token_hash` (only the hash is stored), `expires_at`, `used_at` |
| `patients` | Patient profile | `patient_code`, `date_of_birth`, `gender`, `phone`, `photo_ref`, emergency contact |
| `doctors` | Doctor profile | `doctor_code`, `specialization`, `license_number` |
| `access_requests` | Doctor ↔ patient access | `status` (pending, approved, rejected, revoked), `responded_at`, `revoked_at`, `revoked_by_user_id` |
| `reports` | Uploaded medical reports | `category`, `report_date`, `uploaded_at`, uploader fields, `storage_ref`, `original_filename`, `file_type`, `file_size`, `sha256` |
| `ai_summaries` | Stored AI outputs | `kind`, `subject_id`, `source_ids`, `source_fingerprint` (staleness), `content` (JSON), `provider`, `model`, generator |
| `diabetes_assessments` | Earlier symptom-model results (superseded, read-only history) | `inputs` (the 16 values), `prediction`, `classification_probability`, `model_version`, `lifestyle_snapshot`, performer |
| `diabetes_risk_assessments` | Future diabetes risk estimates (current model, immutable history) | `risk_percent`, `risk_category`, `prediction`, `input_features`/`provenance`/`missing_features` (JSON), `input_fingerprint`, `model_version`, performer |
| `heart_risk_assessments` | Heart disease risk screenings (synthetic-data model `susthiti-heart-v3`, immutable history) | `probability_percent`, `risk_level`, `prediction`, `input_features`/`provenance`/`missing_features` (JSON), `input_fingerprint`, `model_version`, performer |
| `glucose_readings` | Glucose values | `value`, `unit`, `reading_type`, `measured_at`, `context`, `source` |
| `food_entries` | Food log with revisions | `food_name`, `quantity`, `meal_type`, `eaten_at`, `previous_id`, `superseded_at` |
| `lifestyle_metrics` | Steps, heart rate, sleep, activity, blood pressure, SpO2, calories | `metric_type`, `value`, `value2` (diastolic), `unit`, `recorded_at`, `source`, `wearable_connection_id` |
| `wearable_connections` | Connected devices | `provider`, `device_name`, `supported_metrics`, `last_synced_at`, `last_error`, `disconnected_at` |
| `side_effects` | Patient-reported side effects | `severity`, `related_medication`, `occurred_at`, `status`, `priority_flag` |
| `side_effect_events` | Status history and doctor responses | `status`, `response_type`, `message`, actor |
| `appointment_recommendations` | Doctor recommendations | `reason`, `recommended_for`, `side_effect_id` |
| `visits` | Doctor visits | `visit_date`, `reason`, `clinical_notes`, `assessment`, `doctor_reasoning`, `treatment_decision`, `follow_up_date`, `instructions` |
| `prescriptions`, `prescription_items` | Structured prescriptions | header: `prescribed_on`, `instructions`, `notes`, `follow_up_date`; items: `medicine`, `dosage`, `frequency`, `duration`, `instructions` |
| `notifications` | In-app notifications | `type`, `title`, `body`, entity link, `is_read`, `dedupe_key` |
| `notification_preferences` | Per-user reminder switches | food, lifestyle, follow-up, doctor updates |
| `audit_logs` | Security and activity trail | actor, `action`, entity type and label, non-sensitive `details` |
| `counters` | Sequences for human-readable codes | |
| `system_settings` | Admin-editable, non-secret settings | `key`, `value` |

## Files

Uploaded report files and profile photos are stored by `LocalFileStorage` under `STORAGE_DIR` with random
references. The database stores only the reference, the original filename, type, size and SHA-256. Files are
read back only through authorized endpoints. To use object storage, implement the same interface
(`save`, `read`) in `app/services/storage.py` with a private bucket.

## Backups

Back up the database and `STORAGE_DIR` together, since reports need both. Both contain health data: encrypt
backups and restrict who can restore them.

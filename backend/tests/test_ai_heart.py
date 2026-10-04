"""Heart disease risk screening data flowing into the existing AI summary architecture
(patient summary, patient-friendly summary, lifestyle insight, assessment interpretation).
No separate AI system: these all reuse routers/ai.py's existing endpoints, now heart-aware.
Covers: no heart assessment, heart assessment only, diabetes + heart together, multiple
historical heart assessments, heart + diabetes + report together, missing/no-history data,
and the new heart interpretation endpoint + its own safety patterns.
"""

from app.models import AISummary
from tests.conftest import grant_access, make_admin, make_doctor, register_patient, upload

API = "/api/v1"


def assess_heart(client, headers, pid, fields=None):
    r = client.post(f"{API}/patients/{pid}/heart-risk", headers=headers, json={"fields": fields} if fields else {})
    assert r.status_code == 201, r.text
    return r.json()["assessment"]


def assess_diabetes(client, headers, pid):
    r = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    assert r.status_code == 201, r.text
    return r.json()["assessment"]


def _summary_count(db_module, patient_id: str) -> int:
    with db_module.SessionLocal() as db:
        return db.query(AISummary).filter_by(patient_id=patient_id).count()


# ---------- Patient summary: heart data presence/absence ----------

def test_patient_summary_without_any_heart_assessment_does_not_mention_heart_falsely(env, heart_ml):
    """No heart assessment exists: the record's heart_risk_assessments list is empty and the
    AI must not be asked to narrate something that isn't there."""
    client, ml, gemini = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doctor_headers, patient_headers, patient)
    upload(client, doctor_headers, pid)
    gemini.queue_json({"current_status": "No heart screening on file.", "heart_history": "No records available"})
    r = client.post(f"{API}/patients/{pid}/patient-summary", headers=doctor_headers)
    assert r.status_code == 201, r.text
    sent_text = gemini.requests[0]["messages"][1]["content"][0]["text"]
    assert '"heart_risk_assessments": []' in sent_text  # present, genuinely empty, not omitted


def test_patient_summary_with_heart_only_includes_it_and_stays_cache_correct(env, heart_ml):
    client, ml, gemini = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doctor_headers, patient_headers, patient)
    assess_heart(client, patient_headers, pid)
    gemini.queue_json({"current_status": "Heart screening on file.", "heart_history": "One heart risk screening on record."})
    first = client.post(f"{API}/patients/{pid}/patient-summary", headers=doctor_headers)
    assert first.status_code == 201 and first.json()["created"] is True
    assert first.json()["summary"]["content"]["heart_history"] == "One heart risk screening on record."

    same = client.post(f"{API}/patients/{pid}/patient-summary", headers=doctor_headers)
    assert same.status_code == 200 and same.json()["created"] is False  # unchanged, reused
    assert len(gemini.requests) == 1

    assess_heart(client, patient_headers, pid, fields={"chest_pain": True})  # new heart data -> stale
    gemini.queue_json({"current_status": "Two heart screenings now.", "heart_history": "Two heart risk screenings on record."})
    after = client.post(f"{API}/patients/{pid}/patient-summary", headers=doctor_headers)
    assert after.status_code == 201 and after.json()["created"] is True
    assert len(gemini.requests) == 2


def test_patient_summary_with_diabetes_and_heart_together(env, heart_ml):
    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assess_diabetes(client, headers, pid)
    assess_heart(client, headers, pid)
    upload(client, headers, pid)  # some documented data too
    gemini.queue_json({"current_status": "Both risk signals on file.", "diabetes_history": "One diabetes risk estimate.", "heart_history": "One heart risk screening."})
    r = client.post(f"{API}/patients/{pid}/patient-summary", headers=headers)
    assert r.status_code == 201, r.text
    content = r.json()["summary"]["content"]
    assert content["diabetes_history"] and content["heart_history"]


def test_multiple_historical_heart_assessments_all_feed_the_summary(env, heart_ml):
    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    heart_ml.probability_percent = 10.0
    assess_heart(client, headers, pid, fields={"chest_pain": False})
    heart_ml.probability_percent = 75.0
    assess_heart(client, headers, pid, fields={"chest_pain": True})
    gemini.queue_json({"current_status": "Heart risk trend reviewed.", "heart_history": "Two heart risk screenings, the most recent higher than the first."})
    r = client.post(f"{API}/patients/{pid}/patient-summary", headers=headers)
    assert r.status_code == 201, r.text
    history = client.get(f"{API}/patients/{pid}/heart-risk/history", headers=headers).json()
    assert history["total"] == 2  # the AI's own record of what to summarize


def test_no_history_patient_cannot_generate_a_summary(env, heart_ml):
    """Guards against the AI inventing a summary (or a heart trend) from nothing."""
    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    r = client.post(f"{API}/patients/{pid}/patient-summary", headers=headers)
    assert r.status_code == 422, r.text
    assert gemini.requests == []


# ---------- Patient-friendly summary ----------

def test_friendly_summary_describes_heart_screening_without_diagnosing(env, heart_ml):
    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assess_heart(client, headers, pid)
    gemini.queue_json({"overall": "A heart disease screening tool gave a low risk signal based on the information provided.", "standouts": ["Heart screening: low risk signal"]})
    r = client.post(f"{API}/patients/{pid}/friendly-summary", headers=headers)
    assert r.status_code == 201, r.text
    assert "risk signal" in r.json()["summary"]["content"]["overall"]


# ---------- Lifestyle insight sees the heart screening as context ----------

def test_lifestyle_insight_includes_heart_screening_context(env, heart_ml):
    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assess_heart(client, headers, pid)
    client.post(f"{API}/patients/{pid}/glucose", headers=headers, json={"value": 104, "unit": "mg/dL", "reading_type": "fasting", "measured_at": "2026-09-20T08:00:00Z"})
    gemini.queue_json({"headline": "Steady, with a recent heart screening on file."})
    r = client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=headers)
    assert r.status_code == 201, r.text
    import json as _json
    sent = _json.dumps(gemini.requests[-1])
    assert "latest_heart_risk_screening" in sent


# ---------- Heart assessment interpretation (parallel endpoint, diabetes untouched) ----------

def test_heart_interpretation_reuses_and_regenerates_like_diabetes_does(env, heart_ml):
    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    a = assess_heart(client, headers, pid)
    gemini.queue_json({"interpretation": "The heart-disease screening model produced a low risk signal based on the information provided."})
    first = client.post(f"{API}/heart-risk/{a['id']}/interpretation", headers=headers)
    assert first.status_code == 201, first.text
    assert "screening" in first.json()["summary"]["content"]["interpretation"].lower() or "signal" in first.json()["summary"]["content"]["interpretation"].lower()

    same = client.post(f"{API}/heart-risk/{a['id']}/interpretation", headers=headers)
    assert same.status_code == 200 and same.json()["created"] is False
    assert len(gemini.requests) == 1

    gemini.queue_json({"interpretation": "Forced regeneration."})
    forced = client.post(f"{API}/heart-risk/{a['id']}/interpretation", headers=headers, params={"force": "true"})
    assert forced.status_code == 201 and forced.json()["created"] is True
    assert len(gemini.requests) == 2


def test_heart_interpretation_never_calls_it_a_diagnosis(env, heart_ml):
    client, ml, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    a = assess_heart(client, headers, pid)
    gemini.queue_json({"interpretation": "You have heart disease."})
    r = client.post(f"{API}/heart-risk/{a['id']}/interpretation", headers=headers)
    assert r.status_code == 502 and r.json()["detail"]["code"] == "ai_invalid_response"
    assert _summary_count(db_module, pid) == 0


def test_heart_interpretation_overclaim_wording_is_rejected(env, heart_ml):
    """'clinically validated' / 'confirmed diagnosis' language about the synthetic model is
    rejected the same way diagnosis-certainty wording is."""
    client, ml, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    a = assess_heart(client, headers, pid)
    gemini.queue_json({"interpretation": "This is a clinically validated result."})
    r = client.post(f"{API}/heart-risk/{a['id']}/interpretation", headers=headers)
    assert r.status_code == 502 and r.json()["detail"]["code"] == "ai_invalid_response"
    assert _summary_count(db_module, pid) == 0


def test_heart_interpretation_future_onset_claim_is_rejected(env, heart_ml):
    client, ml, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    a = assess_heart(client, headers, pid)
    gemini.queue_json({"interpretation": "You will develop heart disease within 5 years."})
    r = client.post(f"{API}/heart-risk/{a['id']}/interpretation", headers=headers)
    assert r.status_code == 502 and r.json()["detail"]["code"] == "ai_invalid_response"
    assert _summary_count(db_module, pid) == 0


def test_heart_interpretation_is_independent_of_diabetes_interpretation_caching(env, heart_ml):
    """Guards against any cross-wiring between the two sibling interpretation endpoints."""
    from app.models import DiabetesAssessment
    from datetime import datetime, timezone
    from app import db as db_module

    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    heart = assess_heart(client, headers, pid)
    with db_module.SessionLocal() as db:
        from app.models import Patient
        user_id = db.get(Patient, pid).user_id
        db.add(DiabetesAssessment(assessment_code="DA-HRTX1", patient_id=pid, assessed_at=datetime.now(timezone.utc),
                                  model_version="old", inputs={"Age": 40}, prediction="Negative",
                                  performed_by_user_id=user_id, performed_by_role="patient"))
        db.commit()
        diabetes_assessment_id = db.query(DiabetesAssessment).filter_by(assessment_code="DA-HRTX1").one().id

    gemini.queue_json({"interpretation": "Heart: low risk signal."})
    r1 = client.post(f"{API}/heart-risk/{heart['id']}/interpretation", headers=headers)
    assert r1.status_code == 201, r1.text

    gemini.queue_json({"interpretation": "Diabetes: classification reviewed."})
    r2 = client.post(f"{API}/assessments/{diabetes_assessment_id}/interpretation", headers=headers)
    assert r2.status_code == 201, r2.text
    assert r1.json()["summary"]["id"] != r2.json()["summary"]["id"]
    assert len(gemini.requests) == 2


# ---------- Conflicting / missing data ----------

def test_missing_heart_data_is_reported_as_unavailable_not_invented(env, heart_ml):
    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    upload(client, headers, pid)  # documented data exists, but no heart assessment
    gemini.queue_json({"current_status": "Report on file; no heart screening yet.", "heart_history": "No records available"})
    r = client.post(f"{API}/patients/{pid}/patient-summary", headers=headers)
    assert r.status_code == 201, r.text
    assert r.json()["summary"]["content"]["heart_history"] == "No records available"

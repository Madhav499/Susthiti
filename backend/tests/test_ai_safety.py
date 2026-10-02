"""AI output safety validation (services/ai/safety.py). Each test queues a deliberately
unsafe Gemini response and confirms SUSTHITI discards it (502 ai_invalid_response, nothing
stored) rather than ever showing or saving unsafe AI content. A final test confirms an
ordinary, safe response is not falsely rejected.
"""

from app.models import AISummary
from tests.conftest import grant_access, make_admin, make_doctor, register_patient, upload

API = "/api/v1"


def _summary_count(db_module, patient_id: str) -> int:
    with db_module.SessionLocal() as db:
        return db.query(AISummary).filter_by(patient_id=patient_id).count()


def _assert_rejected(client, db_module, pid, response):
    assert response.status_code == 502, response.text
    assert response.json()["detail"]["code"] == "ai_invalid_response"
    assert _summary_count(db_module, pid) == 0


def test_medication_dosage_instruction_is_rejected(env):
    client, _, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, headers, pid).json()
    gemini.queue_json({"summary": "Take 500mg twice daily to manage your levels."})
    _assert_rejected(client, db_module, pid, client.post(f"{API}/reports/{report['id']}/summary", headers=headers))


def test_supplement_dosage_instruction_is_rejected(env):
    client, _, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, headers, pid).json()
    gemini.queue_json({"summary": "Take 1000 IU of vitamin D every morning."})
    _assert_rejected(client, db_module, pid, client.post(f"{API}/reports/{report['id']}/summary", headers=headers))


def test_emergency_declaration_is_rejected(env):
    client, _, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, headers, pid).json()
    gemini.queue_json({"summary": "This is an emergency, go to the ER immediately."})
    _assert_rejected(client, db_module, pid, client.post(f"{API}/reports/{report['id']}/summary", headers=headers))


def test_diagnosis_certainty_in_interpretation_is_rejected(env):
    client, _, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, headers, pid).json()
    gemini.queue_json({"summary": "HbA1c recorded.", "interpretation": "You have diabetes."})
    _assert_rejected(client, db_module, pid, client.post(f"{API}/reports/{report['id']}/summary", headers=headers))


def test_diagnosis_wording_in_a_documented_fact_field_is_not_flagged(env):
    """The diagnosis-certainty check is scoped to advice fields (e.g. "interpretation"), not
    to fields meant to recite documented history, so a real doctor-recorded diagnosis can
    still be narrated as fact without being treated as an unsafe AI claim."""
    client, _, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, headers, pid).json()
    gemini.queue_json({"summary": "Prior doctor visit notes: patient has diabetes, managed with metformin.", "interpretation": "The HbA1c value is within the documented range."})
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201, r.text


def _log_glucose(client, headers, pid):
    return client.post(f"{API}/patients/{pid}/glucose", headers=headers, json={"value": 104, "unit": "mg/dL", "reading_type": "fasting", "measured_at": "2026-09-20T08:00:00Z"})


def test_numeric_target_in_a_suggestion_is_rejected(env):
    client, _, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    _log_glucose(client, headers, pid)
    gemini.queue_json({"headline": "Stay active.", "suggestions": ["Walk exactly 8000 steps every day."]})
    _assert_rejected(client, db_module, pid, client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=headers))


def test_future_onset_probability_claim_is_rejected(env):
    client, _, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    _log_glucose(client, headers, pid)
    gemini.queue_json({"headline": "Pattern review.", "interpretation": "You will develop diabetes within 5 years."})
    _assert_rejected(client, db_module, pid, client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=headers))


def test_suggestion_conflicting_with_a_documented_allergy_is_rejected(env):
    client, _, gemini = env
    from app import db as db_module

    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    client.put(f"{API}/patients/{pid}/health-profile", headers=headers, json={"values": {"allergies": ["peanuts"]}})
    _log_glucose(client, headers, pid)
    gemini.queue_json({"headline": "Snack ideas.", "suggestions": ["Try adding peanut butter to breakfast."]})
    _assert_rejected(client, db_module, pid, client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=headers))


def test_suggestion_respecting_a_documented_restriction_is_not_flagged(env):
    """A suggestion that correctly tells the patient to avoid a restricted activity must not
    be rejected just because it names it."""
    client, _, gemini = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doctor_headers, patient_headers, patient)
    client.put(f"{API}/patients/{pid}/health-profile", headers=doctor_headers, json={"values": {"doctor_restrictions": ["no high-intensity exercise"]}})
    _log_glucose(client, patient_headers, pid)
    gemini.queue_json({"headline": "Gentle movement.", "suggestions": ["Avoid high-intensity exercise and prefer a short daily walk instead."]})
    r = client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=patient_headers)
    assert r.status_code == 201, r.text


def test_an_ordinary_safe_response_is_not_falsely_rejected(env):
    client, _, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, headers, pid).json()
    gemini.queue_json({
        "summary": "HbA1c recorded at 6.1%.",
        "key_findings": ["HbA1c 6.1%"],
        "relevant_values": [{"name": "HbA1c", "value": "6.1", "unit": "%", "reference_range": "4.0-5.6", "note": None}],
        "interpretation": "This value is slightly above the typical reference range. Discuss with your doctor.",
        "questions_for_doctor": ["What does this mean for my next steps?"],
    })
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201, r.text
    assert r.json()["summary"]["content"]["summary"] == "HbA1c recorded at 6.1%."

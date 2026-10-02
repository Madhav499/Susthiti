"""Regenerating an AI summary skips the AI call and reuses the stored result when the
source data and prompt version are unchanged; `force=true` always calls the AI again.
Covers a representative subset of the 5 AI endpoints -- they all share the same
_reusable() helper in routers/ai.py, so this is not exhaustive by design.
"""

from tests.conftest import grant_access, make_admin, make_doctor, register_patient, upload

API = "/api/v1"


def test_report_summary_reuses_an_unchanged_result_unless_forced(env):
    client, _, gemini = env
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()

    gemini.queue_json({"summary": "First pass."})
    first = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert first.status_code == 201 and first.json()["created"] is True

    same = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert same.status_code == 200, same.text
    assert same.json()["created"] is False
    assert same.json()["summary"]["id"] == first.json()["summary"]["id"]
    assert len(gemini.requests) == 1  # the AI was not called a second time

    gemini.queue_json({"summary": "Forced regeneration."})
    forced = client.post(f"{API}/reports/{report['id']}/summary", headers=headers, params={"force": "true"})
    assert forced.status_code == 201
    assert forced.json()["created"] is True
    assert forced.json()["summary"]["id"] != first.json()["summary"]["id"]
    assert len(gemini.requests) == 2


def test_all_reports_summary_reuses_an_unchanged_result_unless_forced(env):
    client, _, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    upload(client, headers, pid, report_date="2026-01-05")
    upload(client, headers, pid, report_date="2026-06-05")

    gemini.queue_json({"summary": "Two reports reviewed."})
    first = client.post(f"{API}/patients/{pid}/reports-summary", headers=headers)
    assert first.status_code == 201 and first.json()["created"] is True

    same = client.post(f"{API}/patients/{pid}/reports-summary", headers=headers)
    assert same.status_code == 200 and same.json()["created"] is False
    assert same.json()["summary"]["id"] == first.json()["summary"]["id"]
    assert len(gemini.requests) == 1

    gemini.queue_json({"summary": "Forced."})
    forced = client.post(f"{API}/patients/{pid}/reports-summary", headers=headers, params={"force": "true"})
    assert forced.status_code == 201 and forced.json()["created"] is True
    assert len(gemini.requests) == 2


def test_patient_summary_reuses_an_unchanged_result_unless_forced(env):
    client, _, gemini = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doctor_headers, patient_headers, patient)

    gemini.queue_json({"patient_overview": "45-year-old male."})
    first = client.post(f"{API}/patients/{pid}/patient-summary", headers=doctor_headers)
    assert first.status_code == 201 and first.json()["created"] is True

    same = client.post(f"{API}/patients/{pid}/patient-summary", headers=doctor_headers)
    assert same.status_code == 200 and same.json()["created"] is False
    assert len(gemini.requests) == 1

    # A real change (a new report) makes the cached summary stale, so it regenerates
    # even without force.
    upload(client, doctor_headers, pid)
    gemini.queue_json({"patient_overview": "45-year-old male. One report on file."})
    after_change = client.post(f"{API}/patients/{pid}/patient-summary", headers=doctor_headers)
    assert after_change.status_code == 201 and after_change.json()["created"] is True
    assert len(gemini.requests) == 2


def test_lifestyle_insight_reuses_an_unchanged_result_unless_forced(env):
    client, _, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    client.post(f"{API}/patients/{pid}/glucose", headers=headers, json={"value": 104, "unit": "mg/dL", "reading_type": "fasting", "measured_at": "2026-09-20T08:00:00Z"})

    gemini.queue_json({"headline": "Looks steady."})
    first = client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=headers)
    assert first.status_code == 201 and first.json()["created"] is True

    same = client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=headers)
    assert same.status_code == 200 and same.json()["created"] is False
    assert len(gemini.requests) == 1

    gemini.queue_json({"headline": "Forced."})
    forced = client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=headers, params={"force": "true"})
    assert forced.status_code == 201 and forced.json()["created"] is True
    assert len(gemini.requests) == 2

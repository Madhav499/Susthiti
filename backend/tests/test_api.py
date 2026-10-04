import httpx

from tests.conftest import PDF_BYTES, grant_access, make_admin, make_doctor, register_patient, upload

API = "/api/v1"


# ---------- Authentication & roles ----------

def test_register_login_logout_and_role(env):
    client, _, _ = env
    headers, user = register_patient(client)
    assert user["role"] == "patient" and user["patient_code"].startswith("SUS-P-")
    assert client.get(f"{API}/auth/me", headers=headers).json()["email"] == "patient@example.org"
    login = client.post(f"{API}/auth/login", json={"email": "patient@example.org", "password": "Password1"})
    assert login.status_code == 200
    assert client.post(f"{API}/auth/logout", headers=headers).status_code == 204
    assert client.get(f"{API}/auth/me", headers=headers).status_code == 401


def test_local_web_app_on_any_localhost_port_passes_cors(env):
    """`flutter run -d chrome` serves the app on a random localhost port; development accepts it."""
    from app.main import settings

    client, _, _ = env
    preflight = {"Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "content-type"}
    ok = client.options(f"{API}/auth/login", headers={"Origin": "http://localhost:57506", **preflight})
    assert ok.status_code == 200
    assert ok.headers["access-control-allow-origin"] in ("http://localhost:57506", "*")
    if "*" not in settings.cors_origin_list:
        lookalike = client.options(f"{API}/auth/login", headers={"Origin": "http://localhost.evil.example", **preflight})
        assert "access-control-allow-origin" not in lookalike.headers


def test_demo_style_test_domain_emails_can_sign_in(env):
    """DEMO accounts use the reserved .test domain; login must accept them (format check only)."""
    client, _, _ = env
    register_patient(client, email="Demo.Patient@susthiti.test")
    login = client.post(f"{API}/auth/login", json={"email": "demo.patient@susthiti.test", "password": "Password1"})
    assert login.status_code == 200
    bad = client.post(f"{API}/auth/login", json={"email": "not-an-email", "password": "Password1"})
    assert bad.status_code == 422 and bad.json()["detail"]["message"] == "Enter a valid email address."


def test_wrong_password_and_weak_password(env):
    client, _, _ = env
    register_patient(client)
    assert client.post(f"{API}/auth/login", json={"email": "patient@example.org", "password": "nope"}).status_code == 401
    r = client.post(f"{API}/auth/register", json={"full_name": "A B", "email": "x@example.org", "password": "password", "date_of_birth": "1990-01-01", "gender": "Male"})
    assert r.status_code == 422


def test_password_recovery(env):
    client, _, _ = env
    register_patient(client)
    r = client.post(f"{API}/auth/forgot-password", json={"email": "patient@example.org"})
    token = r.json()["dev_reset_token"]
    assert client.post(f"{API}/auth/reset-password", json={"token": token, "new_password": "NewPass123"}).status_code == 200
    assert client.post(f"{API}/auth/login", json={"email": "patient@example.org", "password": "NewPass123"}).status_code == 200
    assert client.post(f"{API}/auth/reset-password", json={"token": token, "new_password": "Another123"}).status_code == 400


def test_patient_cannot_call_admin_api(env):
    client, _, _ = env
    headers, _ = register_patient(client)
    assert client.get(f"{API}/admin/dashboard", headers=headers).status_code == 403
    assert client.post(f"{API}/admin/doctors", headers=headers, json={"full_name": "X Y", "email": "d@example.org", "temporary_password": "Password1"}).status_code == 403


def test_no_public_admin_or_doctor_signup(env):
    client, _, _ = env
    r = client.post(f"{API}/auth/register", json={"full_name": "Evil", "email": "e@example.org", "password": "Password1", "date_of_birth": "1990-01-01", "gender": "Male", "role": "admin"})
    assert r.json()["user"]["role"] == "patient"


def test_deactivated_doctor_cannot_sign_in(env):
    client, _, _ = env
    admin = make_admin(client)
    doctor_headers, doctor = make_doctor(client, admin)
    assert client.patch(f"{API}/admin/doctors/{doctor['id']}", headers=admin, json={"is_active": False}).status_code == 200
    assert client.get(f"{API}/auth/me", headers=doctor_headers).status_code == 401
    assert client.post(f"{API}/auth/login", json={"email": "doctor@example.org", "password": "Password1"}).status_code == 403


# ---------- Doctor access ----------

def test_doctor_access_flow(env):
    client, _, _ = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]

    assert client.get(f"{API}/patients/{pid}/reports", headers=doctor_headers).status_code == 403
    wrong = client.post(f"{API}/access-requests", headers=doctor_headers, json={"patient_name": "Someone Else", "patient_code": patient["patient_code"]})
    assert wrong.status_code == 404
    req = client.post(f"{API}/access-requests", headers=doctor_headers, json={"patient_name": "madhav test", "patient_code": patient["patient_code"]}).json()
    assert req["status"] == "pending"
    assert client.get(f"{API}/patients/{pid}/reports", headers=doctor_headers).status_code == 403
    notes = client.get(f"{API}/notifications", headers=patient_headers).json()["items"]
    assert any(n["type"] == "access_request" for n in notes)

    assert client.post(f"{API}/access-requests/{req['id']}/approve", headers=patient_headers).json()["status"] == "approved"
    assert client.get(f"{API}/patients/{pid}/reports", headers=doctor_headers).status_code == 200
    assert len(client.get(f"{API}/doctor/patients", headers=doctor_headers).json()["items"]) == 1

    client.post(f"{API}/access-requests/{req['id']}/revoke", headers=patient_headers)
    assert client.get(f"{API}/patients/{pid}/reports", headers=doctor_headers).status_code == 403


def test_admin_reads_every_record_but_cannot_write_clinical_data(env):
    client, _, _ = env
    admin = make_admin(client)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, patient_headers, pid).json()

    for path in (f"/patients/{pid}/reports", f"/reports/{report['id']}", f"/reports/{report['id']}/file", f"/patients/{pid}/assessments",
                 f"/patients/{pid}/diabetes-risk", f"/patients/{pid}/diabetes-risk/history", f"/patients/{pid}/health-profile", f"/reports/{report['id']}/values",
                 f"/patients/{pid}/glucose", f"/patients/{pid}/food", f"/patients/{pid}/lifestyle/overview", f"/patients/{pid}/prescriptions",
                 f"/patients/{pid}/visits", f"/patients/{pid}/side-effects", f"/patients/{pid}/timeline", f"/patients/{pid}/patient-summary"):
        assert client.get(f"{API}{path}", headers=admin).status_code == 200, path

    # Every clinical write is still refused: admin inspects records, never authors them.
    assert client.post(f"{API}/patients/{pid}/diabetes-risk", headers=admin).status_code == 403
    assert client.put(f"{API}/patients/{pid}/health-profile", headers=admin, json={"values": {"hypertension": True}}).status_code == 403
    assert client.put(f"{API}/reports/{report['id']}/values", headers=admin, json={"values": {"hba1c": {"value": 6.1, "unit": "%"}}}).status_code == 403
    assert client.post(f"{API}/patients/{pid}/glucose", headers=admin, json={"value": 100, "reading_type": "fasting", "measured_at": "2026-09-01T08:00:00Z"}).status_code == 403
    assert client.post(f"{API}/patients/{pid}/prescriptions", headers=admin, json={}).status_code in (403, 422)
    assert client.post(f"{API}/patients/{pid}/side-effects", headers=admin, json={}).status_code in (403, 422)
    assert client.post(f"{API}/reports/{report['id']}/summary", headers=admin).status_code == 403
    assert client.post(f"{API}/patients/{pid}/patient-summary", headers=admin).status_code == 403
    assert upload(client, admin, pid).status_code == 403  # admin uploads go through /admin/patients/{id}/reports


def test_admin_patient_profile_is_audited_and_links_records(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, doctor = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doc, patient_headers, patient)
    rx = _rx(client, doc, pid, "Metformin", "2026-01-10").json()

    profile = client.get(f"{API}/admin/patients/{pid}", headers=admin).json()
    assert profile["patient_code"] == patient["patient_code"] and profile["counts"]["prescriptions"] == 1
    assert [d["doctor"]["id"] for d in profile["doctors"] if d["status"] == "approved"] == [doctor["id"]]

    audit_items = client.get(f"{API}/admin/patients/{pid}/audit", headers=admin).json()["items"]
    viewed = [a for a in audit_items if a["action"] == "patient_record_viewed"]
    assert viewed and viewed[0]["actor_role"] == "admin"
    created = next(a for a in audit_items if a["action"] == "prescription_created")
    assert created["actor_name"] == "Asha Rao" and created["patient"]["id"] == pid and created["entity_id"] == rx["id"]
    # Record views stay out of the dashboard feed.
    assert all(a["action"] != "patient_record_viewed" for a in client.get(f"{API}/admin/dashboard", headers=admin).json()["recent_activity"])


def test_admin_doctor_profile_is_data_driven(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, doctor = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doc, patient_headers, patient)
    _rx(client, doc, pid, "Metformin", "2026-01-10")
    upload(client, doc, pid)
    client.post(f"{API}/patients/{pid}/side-effects", headers=patient_headers, json={"description": "Dizziness", "severity": "moderate", "occurred_at": "2026-09-20T08:00:00Z"})

    profile = client.get(f"{API}/admin/doctors/{doctor['id']}", headers=admin).json()
    stats = profile["stats"]
    assert (stats["active_patients"], stats["prescriptions"], stats["reports_uploaded"], stats["side_effects_pending"]) == (1, 1, 1, 1)
    assert profile["progress"]["patients"] == 1 and profile["progress"]["needs_attention"] == 1

    patients = client.get(f"{API}/admin/doctors/{doctor['id']}/patients", headers=admin).json()["items"]
    assert patients[0]["status"] == "approved" and patients[0]["patient"]["id"] == pid and patients[0]["patient"]["open_side_effects"] == 1
    assert client.get(f"{API}/admin/doctors/{doctor['id']}/prescriptions", headers=admin).json()["items"][0]["patient"]["id"] == pid
    assert client.get(f"{API}/admin/doctors/{doctor['id']}/reports", headers=admin).json()["uploaded"][0]["patient"]["id"] == pid
    assert client.get(f"{API}/admin/doctors/{doctor['id']}/side-effects", headers=admin).json()["pending"] == 1
    actions = client.get(f"{API}/admin/doctors/{doctor['id']}/activity", headers=admin).json()["items"]
    assert {"prescription_created", "report_uploaded", "access_requested"} <= {a["action"] for a in actions}
    audit_trail = client.get(f"{API}/admin/doctors/{doctor['id']}/activity?scope=audit", headers=admin).json()["items"]
    assert any(a["action"] == "doctor_created" for a in audit_trail) and any(a["action"] == "access_approved" for a in audit_trail)

    listed = client.get(f"{API}/admin/doctors", headers=admin).json()["items"][0]
    assert listed["active_patients"] == 1 and listed["last_activity_at"]
    assert client.get(f"{API}/admin/doctors/{doctor['id']}", headers=doc).status_code == 403
    assert client.get(f"{API}/admin/doctors/missing", headers=admin).status_code == 404


def test_admin_sees_follow_up_tasks_and_surgeries_for_a_doctor(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, doctor = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doc, patient_headers, patient)
    due = (datetime.now(timezone.utc).date() + timedelta(days=5)).isoformat()
    when = (datetime.now(timezone.utc) + timedelta(days=10)).isoformat()
    client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Check wound healing", "due_date": due})
    client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={
        "name": "Appendectomy", "purpose": "Acute appendicitis", "scheduled_at": when, "internal_notes": "Pre-op bloods normal.",
    })

    profile = client.get(f"{API}/admin/doctors/{doctor['id']}", headers=admin).json()
    assert profile["stats"]["upcoming_follow_ups"] == 1 and profile["stats"]["upcoming_surgeries"] == 1

    sched = client.get(f"{API}/admin/doctors/{doctor['id']}/appointments", headers=admin).json()
    task = next(f for f in sched["follow_ups"] if f["source"] == "follow_up_task")
    assert task["reason"] == "Check wound healing" and task["status"] == "scheduled" and task["patient"]["id"] == pid
    assert len(sched["surgeries"]) == 1
    surgery = sched["surgeries"][0]
    assert surgery["name"] == "Appendectomy" and surgery["internal_notes"] == "Pre-op bloods normal." and surgery["patient"]["id"] == pid


def test_admin_dashboard_operational_metrics(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    when = (datetime.now(timezone.utc) + timedelta(days=3)).isoformat()
    due = (datetime.now(timezone.utc).date() + timedelta(days=3)).isoformat()
    client.post(f"{API}/patients/{pid}/appointment-recommendations", headers=doc, json={"reason": "Check-up", "recommended_for": when})
    client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Recheck", "due_date": due})
    client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Minor surgery", "purpose": "Routine", "scheduled_at": when})
    upload(client, patient_headers, pid)

    metrics = client.get(f"{API}/admin/dashboard", headers=admin).json()["metrics"]
    assert metrics["appointments_7d"] == 1 and metrics["follow_ups_scheduled"] == 1 and metrics["surgeries_scheduled"] == 1 and metrics["reports_7d"] == 1


def test_admin_edits_patient_details_only(env):
    client, _, _ = env
    admin = make_admin(client)
    _, patient = register_patient(client)
    pid = patient["patient_id"]
    r = client.patch(f"{API}/admin/patients/{pid}", headers=admin, json={"full_name": "Madhav P", "emergency_name": "Asha", "emergency_phone": "+91 98765 43210"})
    assert r.status_code == 200 and r.json()["full_name"] == "Madhav P" and r.json()["emergency_contact"]["name"] == "Asha"
    assert client.patch(f"{API}/admin/patients/{pid}", headers=admin, json={"date_of_birth": "2000-01-01"}).json()["date_of_birth"] == "1990-01-01"
    row = client.get(f"{API}/admin/patients?status=active", headers=admin).json()["items"][0]
    assert row["full_name"] == "Madhav P" and row["age"] is not None
    assert client.get(f"{API}/admin/patients?status=inactive", headers=admin).json()["total"] == 0


def test_patient_cannot_read_another_patient(env):
    client, _, _ = env
    a_headers, _ = register_patient(client)
    _, b = register_patient(client, "Other Person", "b@example.org")
    assert client.get(f"{API}/patients/{b['patient_id']}/glucose", headers=a_headers).status_code == 403


# ---------- Diabetes: see tests/test_diabetes_risk.py ----------

def test_older_database_gains_new_nullable_columns(tmp_path):
    """A database created before model_name/interpretation/disclaimer existed keeps working."""
    import sqlite3

    from app import db as db_module
    from app.db import configure_engine, init_db

    path = tmp_path / "legacy.db"
    with sqlite3.connect(path) as conn:
        conn.execute(
            "CREATE TABLE diabetes_assessments (id VARCHAR(32) PRIMARY KEY, assessment_code VARCHAR(20), patient_id VARCHAR(32), assessed_at DATETIME, "
            "model_version VARCHAR(80), inputs JSON, prediction VARCHAR(20), classification_probability FLOAT, lifestyle_snapshot JSON, "
            "performed_by_user_id VARCHAR(32), performed_by_role VARCHAR(16))"
        )
        conn.execute("INSERT INTO diabetes_assessments (id, prediction) VALUES ('old', 'Negative')")
    previous = db_module.engine.url
    try:
        configure_engine(f"sqlite:///{path}")
        init_db()
        init_db()  # idempotent
    finally:
        configure_engine(str(previous))
    with sqlite3.connect(path) as conn:
        columns = {row[1] for row in conn.execute("PRAGMA table_info(diabetes_assessments)")}
        assert {"model_name", "interpretation", "disclaimer"} <= columns
        assert conn.execute("SELECT prediction, model_name FROM diabetes_assessments WHERE id='old'").fetchone() == ("Negative", None)


# ---------- Reports ----------

def test_report_upload_dates_uploader_and_file(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    r = upload(client, headers, pid)
    assert r.status_code == 201, r.text
    report = r.json()
    assert report["category"] == "hba1c"
    assert report["report_date"] == "2026-01-05"
    assert not report["uploaded_at"].startswith("2026-01-05")
    assert report["uploaded_by"]["role"] == "patient" and report["uploaded_by"]["name"] == "Madhav Test"
    assert report["original_filename"] == "hba1c_jan.pdf"
    f = client.get(f"{API}/reports/{report['id']}/file", headers=headers)
    assert f.status_code == 200 and f.content == PDF_BYTES
    assert "storage" not in str(report) or "storage_ref" not in report


def test_report_validation(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assert upload(client, headers, pid, category="tarot").status_code == 422
    assert upload(client, headers, pid, report_date="2999-01-01").status_code == 422
    assert upload(client, headers, pid, data=b"not a pdf").status_code == 422


def test_report_filters_and_doctor_upload(env):
    client, _, _ = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doctor_headers, patient_headers, patient)
    pid = patient["patient_id"]
    upload(client, patient_headers, pid, "hba1c", "2026-01-05")
    r = upload(client, doctor_headers, pid, "lipid_profile", "2026-03-01", filename="lipids.pdf")
    assert r.json()["uploaded_by"]["role"] == "doctor"
    items = client.get(f"{API}/patients/{pid}/reports?sort=oldest", headers=patient_headers).json()["items"]
    assert [i["category"] for i in items] == ["hba1c", "lipid_profile"]
    assert client.get(f"{API}/patients/{pid}/reports?category=blood", headers=patient_headers).json()["total"] == 1
    assert client.get(f"{API}/patients/{pid}/reports?q=lipids", headers=patient_headers).json()["total"] == 1


def test_analyte_trend_from_confirmed_report_values(env):
    """HbA1c across two confirmed reports is a real trend; an unconfirmed report contributes nothing."""
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    first = upload(client, headers, pid, "hba1c", "2026-01-05").json()
    second = upload(client, headers, pid, "hba1c", "2026-04-10", filename="hba1c_apr.pdf").json()
    upload(client, headers, pid, "hba1c", "2026-06-01", filename="hba1c_jun.pdf")  # left unconfirmed
    client.put(f"{API}/reports/{first['id']}/values", headers=headers, json={"values": {"hba1c": {"value": 6.1, "unit": "%"}}})
    client.put(f"{API}/reports/{second['id']}/values", headers=headers, json={"values": {"hba1c": {"value": 5.8, "unit": "%"}}})
    series = client.get(f"{API}/patients/{pid}/trends", headers=headers, params={"metric": "hba1c", "range": "1y"}).json()
    assert series["unit"] == "%"
    assert [(p["date"][:10], p["value"]) for p in series["points"]] == [("2026-01-05", 6.1), ("2026-04-10", 5.8)]


# ---------- AI ----------

def test_report_summary_success_and_stored(env):
    client, _, gemini = env
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    assert client.get(f"{API}/reports/{report['id']}/summary", headers=headers).json()["summary"] is None
    gemini.queue_json({"summary": "HbA1c recorded.", "key_findings": ["HbA1c 6.1%"], "questions_for_doctor": ["What does this mean?"]})
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201, r.text
    content = r.json()["summary"]["content"]
    assert content["summary"] == "HbA1c recorded." and "does not replace" in content["disclaimer"]
    assert gemini.requests[0]["messages"][1]["content"][1]["file"]["file_data"].startswith("data:application/pdf")
    assert "Do not invent values" in gemini.requests[0]["messages"][0]["content"]
    assert client.get(f"{API}/reports/{report['id']}/summary", headers=headers).json()["summary"]["id"] == r.json()["summary"]["id"]
    pdf = client.get(f"{API}/ai-summaries/{r.json()['summary']['id']}/pdf", headers=headers)
    assert pdf.status_code == 200 and pdf.content.startswith(b"%PDF")
    assert "SUSTHITI_Individual_Report_Summary_" in pdf.headers["content-disposition"]


def test_doctor_reads_the_same_report_summary_the_patient_generated(env):
    """The exact behavior Part 12/23 of the AI-summary spec demands: a doctor with access reads
    the patient's already-generated summary through the same GET a patient uses, and opening it
    never places a second call to the AI provider."""
    client, _, gemini = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doctor_headers, patient_headers, patient)
    report = upload(client, patient_headers, patient["patient_id"]).json()

    gemini.queue_json({"summary": "HbA1c recorded.", "key_findings": ["HbA1c 6.1%"]})
    generated = client.post(f"{API}/reports/{report['id']}/summary", headers=patient_headers)
    assert generated.status_code == 201
    summary_id = generated.json()["summary"]["id"]
    assert len(gemini.requests) == 1  # exactly one AI call so far

    doctor_view = client.get(f"{API}/reports/{report['id']}/summary", headers=doctor_headers)
    assert doctor_view.status_code == 200
    assert doctor_view.json()["summary"]["id"] == summary_id
    assert doctor_view.json()["summary"]["content"]["summary"] == "HbA1c recorded."
    assert len(gemini.requests) == 1  # reading it as the doctor placed no new AI request

    # An unauthorized doctor must not reach it at all.
    other_doctor_headers, _ = make_doctor(client, admin, email="other-doctor@example.org")
    assert client.get(f"{API}/reports/{report['id']}/summary", headers=other_doctor_headers).status_code == 403


def test_ai_invalid_response_then_retry(env):
    client, _, gemini = env
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    gemini.queue_raw(httpx.Response(200, json={"choices": [{"message": {"content": "not json at all"}}]}))
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 502 and r.json()["detail"]["code"] == "ai_invalid_response"
    # original report still available
    assert client.get(f"{API}/reports/{report['id']}/file", headers=headers).status_code == 200
    gemini.queue_json({"summary": "ok"})
    assert client.post(f"{API}/reports/{report['id']}/summary", headers=headers).status_code == 201


def test_ai_api_failure(env, monkeypatch):
    client, _, gemini = env
    from app.services.ai import openrouter as openrouter_module

    monkeypatch.setattr(openrouter_module.time, "sleep", lambda seconds: None)
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    gemini.queue_raw(httpx.Response(500))  # every further call also gets a 500 (FakeGemini default)
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 503 and r.json()["detail"]["code"] == "ai_service_unavailable"
    assert len(gemini.requests) == 3  # retried twice (bounded) before giving up


def test_all_reports_summary_staleness(env):
    client, _, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    upload(client, headers, pid, report_date="2026-01-05")
    assert client.post(f"{API}/patients/{pid}/reports-summary", headers=headers).status_code == 422  # needs 2+
    upload(client, headers, pid, report_date="2026-06-05")
    gemini.queue_json({"summary": "Two HbA1c reports.", "observed_trends": [{"parameter": "HbA1c", "earlier": {"value": "7.1%", "date": "2026-01-05"}, "latest": {"value": "6.4%", "date": "2026-06-05"}, "observed_change": "Lower"}]})
    r = client.post(f"{API}/patients/{pid}/reports-summary", headers=headers)
    assert r.status_code == 201 and r.json()["summary"]["is_stale"] is False
    upload(client, headers, pid, report_date="2026-09-01")
    assert client.get(f"{API}/patients/{pid}/reports-summary", headers=headers).json()["summary"]["is_stale"] is True


def test_patient_summary_for_doctor(env):
    client, _, gemini = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doctor_headers, patient_headers, patient)
    upload(client, doctor_headers, patient["patient_id"])  # some data is required before a summary can generate
    gemini.queue_json({"current_status": "45-year-old male.", "attention_items": ["Sleep"]})
    r = client.post(f"{API}/patients/{patient['patient_id']}/patient-summary", headers=doctor_headers)
    assert r.status_code == 201, r.text
    assert r.json()["summary"]["generated_by_role"] == "doctor"


def test_ai_not_configured(env):
    client, _, _ = env
    from app.services.ai import services as ai_services
    from app.services.ai.openrouter import OpenRouterClient

    ai_services.set_ai_client(OpenRouterClient(api_key=""))
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 503 and r.json()["detail"]["code"] == "ai_not_configured"


def test_prompt_version_is_stored_and_a_later_bump_marks_the_summary_stale(env, monkeypatch):
    client, _, gemini = env
    from app import db as db_module
    from app.models import AISummary
    from app.services.ai.services import ReportSummaryService

    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    gemini.queue_json({"summary": "HbA1c recorded."})
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201 and r.json()["summary"]["is_stale"] is False
    with db_module.SessionLocal() as db:
        stored = db.query(AISummary).filter_by(patient_id=patient["patient_id"]).one()
        assert stored.prompt_version == ReportSummaryService.PROMPT_VERSION
    monkeypatch.setattr(ReportSummaryService, "PROMPT_VERSION", "report-summary-v2")
    assert client.get(f"{API}/reports/{report['id']}/summary", headers=headers).json()["summary"]["is_stale"] is True


# ---------- Allergies & doctor restrictions ----------

def test_patient_can_record_their_own_allergies(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    r = client.put(f"{API}/patients/{pid}/health-profile", headers=headers, json={"values": {"allergies": ["Penicillin", "  peanuts  ", "Penicillin"]}})
    assert r.status_code == 200, r.text
    field = next(f for f in r.json()["fields"] if f["key"] == "allergies")
    assert field["value"] == ["Penicillin", "peanuts"] and field["recorded_by_role"] == "patient"


def test_only_a_doctor_can_record_doctor_restrictions(env):
    client, _, _ = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doctor_headers, patient_headers, patient)
    denied = client.put(f"{API}/patients/{pid}/health-profile", headers=patient_headers, json={"values": {"doctor_restrictions": ["No high-intensity exercise"]}})
    assert denied.status_code == 403
    allowed = client.put(f"{API}/patients/{pid}/health-profile", headers=doctor_headers, json={"values": {"doctor_restrictions": ["No high-intensity exercise"]}})
    assert allowed.status_code == 200, allowed.text
    field = next(f for f in allowed.json()["fields"] if f["key"] == "doctor_restrictions")
    assert field["value"] == ["No high-intensity exercise"] and field["recorded_by_role"] == "doctor"
    # the patient can still read a doctor-recorded restriction, just never write one
    read_back = client.get(f"{API}/patients/{pid}/health-profile", headers=patient_headers).json()
    assert next(f for f in read_back["fields"] if f["key"] == "doctor_restrictions")["value"] == ["No high-intensity exercise"]


def test_lifestyle_ai_context_includes_allergies_and_restrictions(env):
    client, _, gemini = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doctor_headers, patient_headers, patient)
    client.put(f"{API}/patients/{pid}/health-profile", headers=patient_headers, json={"values": {"allergies": ["peanuts"]}})
    client.put(f"{API}/patients/{pid}/health-profile", headers=doctor_headers, json={"values": {"doctor_restrictions": ["avoid high-sodium food"]}})
    client.post(f"{API}/patients/{pid}/glucose", headers=patient_headers, json={"value": 104, "unit": "mg/dL", "reading_type": "fasting", "measured_at": "2026-09-20T08:00:00Z"})
    gemini.queue_json({"headline": "Looks steady.", "suggestions": ["Keep up regular meals."]})
    r = client.post(f"{API}/patients/{pid}/lifestyle-insight", headers=patient_headers)
    assert r.status_code == 201, r.text
    sent = gemini.requests[-1]["messages"][1]["content"][0]["text"]
    assert "peanuts" in sent and "avoid high-sodium food" in sent
    assert "allergies" in gemini.requests[-1]["messages"][0]["content"]


# ---------- Prescriptions ----------

def _rx(client, headers, pid, medicine, day):
    return client.post(f"{API}/patients/{pid}/prescriptions", headers=headers, json={
        "prescribed_on": day, "medicines": [{"medicine": medicine, "dosage": "500 mg", "frequency": "Twice daily", "duration": "30 days", "instructions": "After meals"}],
        "follow_up_date": None,
    })


def test_prescriptions_never_overwrite_and_keep_author(env):
    client, _, _ = env
    admin = make_admin(client)
    doc_a, _ = make_doctor(client, admin, "a@example.org", "Asha Rao")
    doc_b, _ = make_doctor(client, admin, "b@example.org", "Vikram Shah")
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doc_a, patient_headers, patient)
    first = _rx(client, doc_a, pid, "Metformin", "2026-01-10").json()
    grant_access(client, doc_b, patient_headers, patient)
    second = _rx(client, doc_b, pid, "Metformin XR", "2026-06-10").json()
    assert first["prescription_code"] != second["prescription_code"]
    history = client.get(f"{API}/patients/{pid}/prescriptions", headers=doc_b).json()["items"]
    assert [(h["doctor_name"], h["medicines"][0]["medicine"]) for h in history] == [("Vikram Shah", "Metformin XR"), ("Asha Rao", "Metformin")]
    assert client.put(f"{API}/prescriptions/{first['id']}", headers=doc_a, json={}).status_code == 405
    assert client.get(f"{API}/patients/{pid}/prescriptions?q=xr", headers=patient_headers).json()["items"][0]["id"] == second["id"]


def test_duplicate_prescription_same_day_is_rejected(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    grant_access(client, doc, patient_headers, patient)
    first = _rx(client, doc, pid, "Metformin", "2026-01-10")
    assert first.status_code == 201, first.text
    duplicate = _rx(client, doc, pid, "Metformin", "2026-01-10")
    assert duplicate.status_code == 409 and duplicate.json()["detail"]["code"] == "conflict"
    # a different medicine, a different date, or a different doctor is not a duplicate
    assert _rx(client, doc, pid, "Metformin XR", "2026-01-10").status_code == 201
    assert _rx(client, doc, pid, "Metformin", "2026-01-11").status_code == 201
    other_doc, _ = make_doctor(client, admin, "second@example.org", "Second Doctor")
    grant_access(client, other_doc, patient_headers, patient)
    assert _rx(client, other_doc, pid, "Metformin", "2026-01-10").status_code == 201


def test_patient_cannot_create_prescription(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    assert _rx(client, headers, patient["patient_id"], "X", "2026-01-01").status_code == 403


def test_prescription_validation(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    r = client.post(f"{API}/patients/{patient['patient_id']}/prescriptions", headers=doc, json={"prescribed_on": "2026-01-01", "medicines": []})
    assert r.status_code == 422


# ---------- Side effects ----------

def test_side_effect_flow(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    r = client.post(f"{API}/patients/{pid}/side-effects", headers=patient_headers, json={"description": "Nausea after tablets", "severity": "severe", "related_medication": "Metformin", "occurred_at": "2026-09-20T08:00:00Z"})
    effect = r.json()
    assert effect["priority_flag"] is True and effect["status"] == "new"
    assert any(n["type"] == "new_side_effect" for n in client.get(f"{API}/notifications", headers=doc).json()["items"])
    r = client.post(f"{API}/side-effects/{effect['id']}/responses", headers=doc, json={"response_type": "appointment_recommended", "message": "Please come in.", "appointment_reason": "Review medication tolerance"})
    assert r.status_code == 201
    detail = r.json()
    assert detail["status"] == "appointment_recommended"
    assert [h["status"] for h in detail["history"]] == ["new", "appointment_recommended"]
    types = {n["type"] for n in client.get(f"{API}/notifications", headers=patient_headers).json()["items"]}
    assert {"doctor_response", "appointment_recommendation"} <= types
    assert len(client.get(f"{API}/patients/{pid}/appointment-recommendations", headers=patient_headers).json()["items"]) == 1
    assert client.post(f"{API}/side-effects/{effect['id']}/responses", headers=patient_headers, json={"response_type": "monitor"}).status_code == 403


def test_side_effect_validation(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    r = client.post(f"{API}/patients/{patient['patient_id']}/side-effects", headers=headers, json={"description": "x", "severity": "catastrophic", "occurred_at": "2026-09-20T08:00:00Z"})
    assert r.status_code == 422


# ---------- Tracking ----------

def test_glucose_food_lifestyle(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assert client.post(f"{API}/patients/{pid}/glucose", headers=headers, json={"value": 5000, "unit": "mg/dL", "reading_type": "fasting", "measured_at": "2026-09-20T08:00:00Z"}).status_code == 422
    assert client.post(f"{API}/patients/{pid}/glucose", headers=headers, json={"value": 104, "unit": "mg/dL", "reading_type": "fasting", "measured_at": "2026-09-20T08:00:00Z"}).status_code == 201
    assert client.get(f"{API}/patients/{pid}/glucose", headers=headers).json()["total"] == 1

    food = client.post(f"{API}/patients/{pid}/food", headers=headers, json={"food_name": "Rice", "quantity": "2 bowls", "meal_type": "lunch", "eaten_at": "2026-09-20T13:30:00Z"}).json()
    edited = client.put(f"{API}/food/{food['id']}", headers=headers, json={"food_name": "Rice", "quantity": "1 bowl", "meal_type": "lunch", "eaten_at": "2026-09-20T13:30:00Z"}).json()
    assert edited["previous_id"] == food["id"]
    items = client.get(f"{API}/patients/{pid}/food", headers=headers).json()["items"]
    assert [i["quantity"] for i in items] == ["1 bowl"]
    assert len(client.get(f"{API}/food/{edited['id']}/history", headers=headers).json()["items"]) == 2

    assert client.post(f"{API}/patients/{pid}/lifestyle", headers=headers, json={"metric_type": "blood_pressure", "value": 120, "value2": 130, "recorded_at": "2026-09-20T08:00:00Z"}).status_code == 422
    assert client.post(f"{API}/patients/{pid}/lifestyle", headers=headers, json={"metric_type": "steps", "value": 7420, "recorded_at": "2026-09-20T20:00:00Z"}).status_code == 201


def test_demo_wearable_marks_demo_data(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    providers = {p["id"] for p in client.get(f"{API}/wearables/providers", headers=headers).json()["items"]}
    assert "demo" in providers
    device = client.post(f"{API}/wearables/connect", headers=headers, json={"provider": "demo"}).json()
    result = client.post(f"{API}/wearables/{device['id']}/sync", headers=headers).json()
    assert result["imported"] > 0 and result["device"]["status"] == "connected"
    overview = client.get(f"{API}/patients/{patient['patient_id']}/lifestyle/overview", headers=headers).json()
    assert overview["metrics"]["steps"]["latest"]["is_demo"] is True


def test_real_readings_replace_demo_values_for_the_same_day(env):
    """A DEMO account that later connects a real watch: that day's real steps are shown, never added to DEMO steps."""
    from datetime import date, datetime, timedelta, timezone

    client, _, _ = env
    headers, patient = register_patient(client)
    demo = client.post(f"{API}/wearables/connect", headers=headers, json={"provider": "demo"}).json()
    client.post(f"{API}/wearables/{demo['id']}/sync", headers=headers)
    overview = client.get(f"{API}/patients/{patient['patient_id']}/lifestyle/overview", headers=headers).json()
    demo_latest = overview["metrics"]["steps"]["latest"]
    assert demo_latest["is_demo"] is True

    device = client.post(f"{API}/wearables/connect", headers=headers, json={"provider": "health_connect", "platform": "android", "granted_metrics": ["steps"]}).json()
    now = datetime.now(timezone.utc) - timedelta(minutes=1)
    real = {"metric_type": "steps", "value": 17, "recorded_at": now.isoformat(), "local_date": demo_latest["date"], "daily_total": True}
    assert client.post(f"{API}/wearables/{device['id']}/sync", headers=headers, json={"samples": [real]}).json()["imported"] == 1

    latest = client.get(f"{API}/patients/{patient['patient_id']}/lifestyle/overview", headers=headers).json()["metrics"]["steps"]["latest"]
    assert (latest["date"], latest["value"], latest["is_demo"], latest["sources"]) == (demo_latest["date"], 17, False, ["health_platform"])
    assert date.fromisoformat(latest["date"]) <= date.today() + timedelta(days=1)


def test_on_device_sync_without_data_fails_visibly(env):
    client, _, _ = env
    headers, _ = register_patient(client)
    device = client.post(f"{API}/wearables/connect", headers=headers, json={"provider": "health_connect"}).json()
    result = client.post(f"{API}/wearables/{device['id']}/sync", headers=headers, json={}).json()
    assert result["device"]["status"] == "sync_failed" and result["device"]["last_error"]


# ---------- Visits / timeline / audit ----------

def test_visit_timeline_and_audit(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    v = client.post(f"{API}/patients/{pid}/visits", headers=doc, json={"visit_date": "2026-09-18", "reason": "Routine review", "assessment": "Stable", "follow_up_date": "2026-10-18"})
    assert v.status_code == 201
    upload(client, patient_headers, pid, report_date="2026-09-20")
    timeline = client.get(f"{API}/patients/{pid}/timeline", headers=doc).json()["items"]
    assert [t["type"] for t in timeline][:2] == ["report", "visit"]
    logs = client.get(f"{API}/admin/audit-logs", headers=admin).json()["items"]
    actions = {entry["action"] for entry in logs}
    assert {"access_approved", "visit_recorded", "report_uploaded", "doctor_created"} <= actions
    assert client.get(f"{API}/admin/audit-logs", headers=doc).status_code == 403


def test_doctor_dashboard(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    client.post(f"{API}/patients/{pid}/side-effects", headers=patient_headers, json={"description": "Dizziness", "severity": "moderate", "occurred_at": "2026-09-20T08:00:00Z"})
    client.post(f"{API}/patients/{pid}/appointment-recommendations", headers=doc,
                json={"reason": "Review symptoms", "recommended_for": (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()})
    dash = client.get(f"{API}/doctor/dashboard", headers=doc).json()
    assert dash["metrics"]["patients"] == 1 and dash["metrics"]["open_side_effects"] == 1
    assert dash["metrics"]["upcoming_appointments_7d"] == 1
    assert dash["needs_attention"][0]["patient_code"] == patient["patient_code"]
    admin_dash = client.get(f"{API}/admin/dashboard", headers=admin).json()
    assert admin_dash["metrics"]["total_doctors"] == 1


def test_patient_dashboard_shows_the_soonest_upcoming_appointment(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    soon = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()
    later = (datetime.now(timezone.utc) + timedelta(days=20)).isoformat()
    client.post(f"{API}/patients/{pid}/appointment-recommendations", headers=doc, json={"reason": "Later review", "recommended_for": later})
    client.post(f"{API}/patients/{pid}/appointment-recommendations", headers=doc, json={"reason": "Soon review", "recommended_for": soon})
    dash = client.get(f"{API}/patients/{pid}/dashboard", headers=patient_headers).json()
    assert dash["next_appointment"]["reason"] == "Soon review"


def test_patient_dashboard_falls_back_to_an_unscheduled_appointment(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    client.post(f"{API}/patients/{pid}/appointment-recommendations", headers=doc, json={"reason": "Needs scheduling"})
    dash = client.get(f"{API}/patients/{pid}/dashboard", headers=patient_headers).json()
    assert dash["next_appointment"]["reason"] == "Needs scheduling" and dash["next_appointment"]["recommended_for"] is None


def test_patient_dashboard_shows_the_soonest_scheduled_follow_up(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    soon = (datetime.now(timezone.utc).date() + timedelta(days=5)).isoformat()
    later = (datetime.now(timezone.utc).date() + timedelta(days=20)).isoformat()
    later_followup = client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Later check", "due_date": later}).json()
    soon_followup = client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Soon check", "due_date": soon}).json()
    dash = client.get(f"{API}/patients/{pid}/dashboard", headers=patient_headers).json()
    assert dash["next_follow_up"]["purpose"] == "Soon check"

    # A completed follow-up is never shown as the upcoming one, even if its date was soonest.
    client.post(f"{API}/follow-ups/{later_followup['id']}/complete", headers=doc, json={})
    client.post(f"{API}/follow-ups/{soon_followup['id']}/complete", headers=doc, json={})
    dash_after = client.get(f"{API}/patients/{pid}/dashboard", headers=patient_headers).json()
    assert dash_after["next_follow_up"] is None


# ---------- Follow-ups ----------

def test_follow_up_lifecycle(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    due = (datetime.now(timezone.utc).date() + timedelta(days=10)).isoformat()

    denied = client.post(f"{API}/patients/{pid}/follow-ups", headers=patient_headers, json={"purpose": "Review labs", "due_date": due})
    assert denied.status_code == 403  # a patient cannot schedule their own follow-up

    created = client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Review labs", "due_date": due})
    assert created.status_code == 201
    f = created.json()
    assert f["status"] == "scheduled" and f["due_date"] == due
    assert any(n["type"] == "follow_up_scheduled" for n in client.get(f"{API}/notifications", headers=patient_headers).json()["items"])

    listed = client.get(f"{API}/patients/{pid}/follow-ups", headers=patient_headers).json()["items"]
    assert len(listed) == 1 and listed[0]["id"] == f["id"]

    new_due = (datetime.now(timezone.utc).date() + timedelta(days=17)).isoformat()
    rescheduled = client.post(f"{API}/follow-ups/{f['id']}/reschedule", headers=doc, json={"due_date": new_due})
    assert rescheduled.status_code == 200 and rescheduled.json()["due_date"] == new_due

    completed = client.post(f"{API}/follow-ups/{f['id']}/complete", headers=doc, json={"notes": "Labs reviewed, stable"})
    assert completed.status_code == 200 and completed.json()["status"] == "completed"
    assert client.post(f"{API}/follow-ups/{f['id']}/complete", headers=doc, json={}).status_code == 409  # already closed


def test_follow_up_cancel_and_authorization(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    other_doc, _ = make_doctor(client, admin, email="other@example.org", name="Other Doctor")
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    due = (datetime.now(timezone.utc).date() + timedelta(days=5)).isoformat()
    f = client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Check wound healing", "due_date": due}).json()

    # A doctor without approved access to this patient cannot act on it.
    assert client.post(f"{API}/follow-ups/{f['id']}/cancel", headers=other_doc, json={}).status_code == 403
    assert client.get(f"{API}/patients/{pid}/follow-ups", headers=admin).status_code == 200
    assert client.post(f"{API}/patients/{pid}/follow-ups", headers=admin, json={"purpose": "x", "due_date": due}).status_code == 403

    cancelled = client.post(f"{API}/follow-ups/{f['id']}/cancel", headers=doc, json={"notes": "No longer needed"})
    assert cancelled.status_code == 200 and cancelled.json()["status"] == "cancelled"
    assert any(n["type"] == "follow_up_cancelled" for n in client.get(f"{API}/notifications", headers=patient_headers).json()["items"])


def test_follow_up_cannot_be_scheduled_in_the_past(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    assert client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Too late", "due_date": "2020-01-01"}).status_code == 422


def test_follow_up_counts_toward_doctor_dashboard_and_attention(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    due = (datetime.now(timezone.utc).date() + timedelta(days=3)).isoformat()
    client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Recheck blood pressure", "due_date": due})
    dash = client.get(f"{API}/doctor/dashboard", headers=doc).json()
    assert dash["metrics"]["follow_ups_7d"] == 1
    assert any("Follow-up due" in a["reasons"][0]["reason"] for a in dash["needs_attention"] if a["patient_code"] == patient["patient_code"])


def test_follow_up_reminder_sent_the_day_before_and_on_the_day(env):
    client, _, _ = env
    from datetime import date, datetime, timezone

    from app import db as db_module
    from app.services.reminders import run_reminders

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    # Created with a far-future date (passes the "not in the past" check), then its due_date is
    # set directly to simulate "tomorrow" relative to the fixed "now" used below.
    f = client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Wound check", "due_date": "2099-01-01"}).json()
    with db_module.SessionLocal() as db:
        from app.models import FollowUp
        row = db.get(FollowUp, f["id"])
        row.due_date = date(2026, 9, 21)  # "tomorrow" relative to the fixed "now" used below
        db.commit()
        assert run_reminders(db, datetime(2026, 9, 20, 10, 0, tzinfo=timezone.utc)) >= 1
    types = {n["type"] for n in client.get(f"{API}/notifications", headers=patient_headers).json()["items"]}
    assert "follow_up_reminder" in types


# ---------- Surgeries ----------

def test_surgery_lifecycle_and_field_visibility(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    when = (datetime.now(timezone.utc) + timedelta(days=14)).isoformat()

    denied = client.post(f"{API}/patients/{pid}/surgeries", headers=patient_headers, json={"name": "Appendectomy", "purpose": "Appendicitis", "scheduled_at": when})
    assert denied.status_code == 403  # a patient cannot schedule their own surgery

    created = client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={
        "name": "Appendectomy", "purpose": "Acute appendicitis", "scheduled_at": when, "hospital": "City General",
        "patient_instructions": "Fast for 8 hours beforehand.", "internal_notes": "Pre-op bloods normal; proceed as planned.",
    })
    assert created.status_code == 201
    s = created.json()
    assert s["status"] == "scheduled" and s["internal_notes"] == "Pre-op bloods normal; proceed as planned."
    assert any(n["type"] == "surgery_scheduled" for n in client.get(f"{API}/notifications", headers=patient_headers).json()["items"])

    # The patient sees everything except internal_notes; the doctor and admin see it too.
    patient_view = client.get(f"{API}/patients/{pid}/surgeries", headers=patient_headers).json()["items"][0]
    assert "internal_notes" not in patient_view
    assert patient_view["name"] == "Appendectomy" and patient_view["hospital"] == "City General" and patient_view["patient_instructions"] == "Fast for 8 hours beforehand."
    doctor_view = client.get(f"{API}/patients/{pid}/surgeries", headers=doc).json()["items"][0]
    assert doctor_view["internal_notes"] == "Pre-op bloods normal; proceed as planned."
    admin_view = client.get(f"{API}/patients/{pid}/surgeries", headers=admin).json()["items"][0]
    assert admin_view["internal_notes"] == "Pre-op bloods normal; proceed as planned."

    updated = client.post(f"{API}/surgeries/{s['id']}/update", headers=doc, json={"patient_instructions": "Fast for 12 hours beforehand."})
    assert updated.status_code == 200 and updated.json()["patient_instructions"] == "Fast for 12 hours beforehand."

    new_when = (datetime.now(timezone.utc) + timedelta(days=21)).isoformat()
    rescheduled = client.post(f"{API}/surgeries/{s['id']}/reschedule", headers=doc, json={"scheduled_at": new_when})
    assert rescheduled.status_code == 200

    completed = client.post(f"{API}/surgeries/{s['id']}/complete", headers=doc)
    assert completed.status_code == 200 and completed.json()["status"] == "completed"
    assert client.post(f"{API}/surgeries/{s['id']}/complete", headers=doc).status_code == 409  # already closed


def test_surgery_cancel_and_authorization(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    other_doc, _ = make_doctor(client, admin, email="other2@example.org", name="Other Doctor Two")
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    when = (datetime.now(timezone.utc) + timedelta(days=10)).isoformat()
    s = client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Knee surgery", "purpose": "Torn ligament", "scheduled_at": when}).json()

    assert client.post(f"{API}/surgeries/{s['id']}/cancel", headers=other_doc).status_code == 403
    assert client.get(f"{API}/patients/{pid}/surgeries", headers=admin).status_code == 200
    assert client.post(f"{API}/patients/{pid}/surgeries", headers=admin, json={"name": "x", "purpose": "y"}).status_code == 403

    cancelled = client.post(f"{API}/surgeries/{s['id']}/cancel", headers=doc)
    assert cancelled.status_code == 200 and cancelled.json()["status"] == "cancelled"
    assert any(n["type"] == "surgery_cancelled" for n in client.get(f"{API}/notifications", headers=patient_headers).json()["items"])


def test_surgery_without_a_date_is_allowed_and_shown_as_tbd(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    created = client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Cataract surgery", "purpose": "Vision correction"})
    assert created.status_code == 201 and created.json()["scheduled_at"] is None


def test_patient_dashboard_shows_the_soonest_scheduled_surgery(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    soon = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()
    later = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()
    later_surgery = client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Later surgery", "purpose": "Later reason", "scheduled_at": later})
    assert later_surgery.status_code == 201, later_surgery.text
    soon_surgery = client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Soon surgery", "purpose": "Soon reason", "scheduled_at": soon, "internal_notes": "private"})
    assert soon_surgery.status_code == 201, soon_surgery.text
    dash = client.get(f"{API}/patients/{pid}/dashboard", headers=patient_headers).json()
    assert dash["next_surgery"]["name"] == "Soon surgery"
    assert "internal_notes" not in dash["next_surgery"]  # the dashboard summary never leaks doctor-only fields


def test_doctor_dashboard_counts_upcoming_surgeries(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    when = (datetime.now(timezone.utc) + timedelta(days=3)).isoformat()
    client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Hip replacement", "purpose": "Arthritis", "scheduled_at": when})
    dash = client.get(f"{API}/doctor/dashboard", headers=doc).json()
    assert dash["metrics"]["upcoming_surgeries_7d"] == 1


# ---------- Doctor "My Day" ----------

def test_doctor_my_day_combines_todays_appointments_follow_ups_and_surgeries(env):
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    now = datetime.now(timezone.utc)
    today = now.date()

    appt_time = now.replace(hour=9, minute=0, second=0, microsecond=0)
    r = client.post(f"{API}/patients/{pid}/appointment-recommendations", headers=doc, json={"reason": "Morning check-up", "recommended_for": appt_time.isoformat()})
    assert r.status_code == 201, r.text

    surgery_time = now.replace(hour=23, minute=55, second=0, microsecond=0)
    r = client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Evening procedure", "purpose": "Scheduled late today", "scheduled_at": surgery_time.isoformat()})
    assert r.status_code == 201, r.text

    r = client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Check healing", "due_date": today.isoformat()})
    assert r.status_code == 201, r.text

    # Not today -- must not appear.
    tomorrow = (now + timedelta(days=1)).isoformat()
    client.post(f"{API}/patients/{pid}/appointment-recommendations", headers=doc, json={"reason": "Tomorrow's visit", "recommended_for": tomorrow})

    dash = client.get(f"{API}/doctor/dashboard", headers=doc).json()
    today_items = dash["today"]
    assert [i["type"] for i in today_items] == ["appointment", "surgery", "follow_up"]
    assert today_items[0]["title"] == "Morning check-up" and today_items[0]["patient_code"] == patient["patient_code"]
    assert today_items[2]["at"] is None  # a follow-up has no time of its own


def test_revoked_access_immediately_hides_scheduled_items_from_the_doctor(env):
    """Revoking takes effect immediately everywhere on this dashboard, including items made
    while access was still active -- same principle as the rest of this codebase's security
    model (ARCHITECTURE.md): a revoked doctor loses access right away, not just going forward."""
    client, _, _ = env
    from datetime import datetime, timedelta, timezone

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    now = datetime.now(timezone.utc)
    today = now.date()

    appt_time = now + timedelta(hours=1)
    r1 = client.post(f"{API}/patients/{pid}/appointment-recommendations", headers=doc, json={"reason": "Scheduled before revoke", "recommended_for": appt_time.isoformat()})
    r2 = client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Scheduled before revoke", "purpose": "Routine procedure", "scheduled_at": appt_time.isoformat()})
    r3 = client.post(f"{API}/patients/{pid}/follow-ups", headers=doc, json={"purpose": "Scheduled before revoke", "due_date": today.isoformat()})
    assert r1.status_code == 201 and r2.status_code == 201 and r3.status_code == 201

    before = client.get(f"{API}/doctor/dashboard", headers=doc).json()
    assert len(before["today"]) == 3 and before["metrics"]["upcoming_appointments_7d"] == 1 and before["metrics"]["upcoming_surgeries_7d"] == 1

    request_id = next(r["id"] for r in client.get(f"{API}/access-requests", headers=patient_headers).json()["items"] if r["status"] == "approved")
    assert client.post(f"{API}/access-requests/{request_id}/revoke", headers=patient_headers).status_code == 200

    after = client.get(f"{API}/doctor/dashboard", headers=doc).json()
    assert after["today"] == [] and after["metrics"]["upcoming_appointments_7d"] == 0 and after["metrics"]["upcoming_surgeries_7d"] == 0 and after["metrics"]["follow_ups_7d"] == 0


def test_doctor_my_day_is_empty_when_nothing_is_scheduled_today(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    dash = client.get(f"{API}/doctor/dashboard", headers=doc).json()
    assert dash["today"] == []


def test_surgery_reminder_sent_the_day_before_and_on_the_day(env):
    client, _, _ = env
    from datetime import datetime, timezone

    from app import db as db_module
    from app.services.reminders import run_reminders

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    pid = patient["patient_id"]
    s = client.post(f"{API}/patients/{pid}/surgeries", headers=doc, json={"name": "Wisdom tooth extraction", "purpose": "Impaction", "scheduled_at": "2099-01-01T09:00:00Z"}).json()
    with db_module.SessionLocal() as db:
        from app.models import Surgery

        row = db.get(Surgery, s["id"])
        row.scheduled_at = datetime(2026, 9, 21, 9, 0, tzinfo=timezone.utc)  # "tomorrow" relative to the fixed "now" below
        db.commit()
        assert run_reminders(db, datetime(2026, 9, 20, 10, 0, tzinfo=timezone.utc)) >= 1
    types = {n["type"] for n in client.get(f"{API}/notifications", headers=patient_headers).json()["items"]}
    assert "surgery_reminder" in types


# ---------- Push device tokens ----------

def test_device_token_register_is_idempotent_and_reassigns_on_shared_device(env):
    client, _, _ = env
    headers_a, _ = register_patient(client, email="device-a@example.org")
    headers_b, _ = register_patient(client, email="device-b@example.org")
    token = "fake-fcm-token-abcdefghijklmnop"

    r = client.post(f"{API}/notifications/device-tokens", headers=headers_a, json={"token": token, "platform": "android"})
    assert r.status_code == 201
    r = client.post(f"{API}/notifications/device-tokens", headers=headers_a, json={"token": token, "platform": "android"})
    assert r.status_code == 201  # re-registering the same token is a no-op, not a duplicate

    # The same device, now signed in as a different account: the token moves with it.
    r = client.post(f"{API}/notifications/device-tokens", headers=headers_b, json={"token": token, "platform": "android"})
    assert r.status_code == 201

    # headers_a can no longer unregister a token it doesn't own; it's simply a no-op, not an error.
    assert client.post(f"{API}/notifications/device-tokens/unregister", headers=headers_a, json={"token": token}).status_code == 200
    assert client.post(f"{API}/notifications/device-tokens/unregister", headers=headers_b, json={"token": token}).status_code == 200


def test_notification_creation_is_unaffected_when_fcm_is_not_configured(env):
    """push.send_to_user() is called from inside notify() on every notification -- this must
    never break notification creation just because no Firebase project exists yet."""
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    client.post(f"{API}/notifications/device-tokens", headers=patient_headers, json={"token": "fake-token-for-unconfigured-fcm-test", "platform": "android"})
    r = client.post(f"{API}/access-requests", headers=doc, json={"patient_name": patient["full_name"], "patient_code": patient["patient_code"]})
    assert r.status_code == 201
    assert any(n["type"] == "access_request" for n in client.get(f"{API}/notifications", headers=patient_headers).json()["items"])


def test_push_handles_an_invalid_service_account_file_without_raising(env, monkeypatch):
    """A typo'd or missing FCM_SERVICE_ACCOUNT_JSON path must disable push, not crash the
    backend -- the same "quiet no-op" behavior as having it unset at all."""
    from app.config import get_settings
    from app.services import push

    monkeypatch.setattr(get_settings(), "fcm_service_account_json", "C:/definitely/does/not/exist.json")
    push._app.cache_clear()
    try:
        assert push._app() is None
    finally:
        push._app.cache_clear()


def test_push_channel_assignment_matches_every_notification_type_in_use(env):
    """Every `notify(..., type=...)` this codebase actually calls with must resolve to a real
    channel, not silently fall through -- and nothing is "important"/high priority by accident,
    since that's exactly the over-alerting the push design explicitly avoids."""
    import re
    from pathlib import Path

    from app.services import push

    app_dir = Path(push.__file__).resolve().parents[1]  # backend/app
    used_types = set()
    for py in (app_dir / "routers").rglob("*.py"):
        for m in re.finditer(r'notify\(\s*db,\s*[^,]+,\s*"([a-z_]+)"', py.read_text()):
            used_types.add(m.group(1))
    for py in (app_dir / "services").rglob("*.py"):
        for m in re.finditer(r'notify\(\s*db,\s*[^,]+,\s*"([a-z_]+)"', py.read_text()):
            used_types.add(m.group(1))
    assert {"access_request", "surgery_scheduled", "new_report", "food_reminder"} <= used_types

    for t in used_types:
        channel_id, priority = push._channel_for(t)
        assert channel_id in {"susthiti_important", "susthiti_appointments", "susthiti_health", "susthiti_general"}
        assert priority in {"high", "normal"}
    # Routine, non-actionable types must never be high priority -- the user can't mute an
    # individual push the way they can an in-app preference, so this is the only brake.
    assert push._channel_for("food_reminder") == ("susthiti_general", "normal")
    assert push._channel_for("birthday") == ("susthiti_general", "normal")
    assert push._channel_for("surgery_reminder") == ("susthiti_important", "high")
    assert push._channel_for(None) == ("susthiti_general", "normal")
    assert push._channel_for("some_future_type_nobody_mapped_yet") == ("susthiti_general", "normal")


def test_admin_sees_notification_delivery_status(env):
    """Admin gets delivery status only -- type, recipient role, outcome -- never a
    notification's title or body."""
    client, _, _ = env
    from app import db as db_module
    from app.models import Notification
    from sqlalchemy import select as sa_select

    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    r = client.post(f"{API}/access-requests", headers=doc, json={"patient_name": patient["full_name"], "patient_code": patient["patient_code"]})
    assert r.status_code == 201

    # FCM is unconfigured in tests, so every real notification lands with push_status=None
    # (nothing attempted) -- confirm that, and confirm no title/body leaks into this view.
    unconfigured = client.get(f"{API}/admin/notifications/delivery", headers=admin).json()
    assert unconfigured["total"] >= 1
    item = unconfigured["items"][0]
    assert item["push_status"] is None and item["recipient_role"] == "patient"
    assert "title" not in item and "body" not in item
    assert client.get(f"{API}/admin/notifications/delivery", headers=doc).status_code == 403

    # Simulate the outcomes FCM would report in production, to verify filtering and the
    # dashboard metric without needing a real Firebase project.
    with db_module.SessionLocal() as db:
        row = db.scalars(sa_select(Notification).where(Notification.type == "access_request")).first()
        row.push_status = "failed"
        db.commit()

    failed = client.get(f"{API}/admin/notifications/delivery", headers=admin, params={"status": "failed"}).json()
    assert failed["total"] == 1 and failed["items"][0]["push_status"] == "failed"
    none_only = client.get(f"{API}/admin/notifications/delivery", headers=admin, params={"status": "none"}).json()
    assert all(i["push_status"] is None for i in none_only["items"])
    dash = client.get(f"{API}/admin/dashboard", headers=admin).json()
    assert dash["metrics"]["failed_push_notifications_7d"] == 1


def test_reminders_respect_preferences(env):
    client, _, _ = env
    from datetime import datetime, timezone

    from app import db as db_module
    from app.services.reminders import run_reminders

    headers, _ = register_patient(client)
    with db_module.SessionLocal() as db:
        assert run_reminders(db, datetime(2026, 9, 25, 20, 0, tzinfo=timezone.utc)) == 1
        assert run_reminders(db, datetime(2026, 9, 25, 21, 0, tzinfo=timezone.utc)) == 0  # dedup
    client.put(f"{API}/notifications/preferences", headers=headers, json={"food_reminders": False})
    with db_module.SessionLocal() as db:
        assert run_reminders(db, datetime(2026, 9, 26, 20, 0, tzinfo=timezone.utc)) == 0


def test_health_reports_model_service_reachability(env):
    client, _, _ = env
    body = client.get("/health").json()
    assert body["status"] == "ok" and body["model_service"] in ("ok", "not_ready", "unreachable")


def _health_samples(day="2026-09-20"):
    return [
        {"metric_type": "steps", "value": 4200, "recorded_at": f"{day}T14:00:00+05:30", "started_at": f"{day}T00:00:00+05:30", "local_date": day, "daily_total": True},
        {"metric_type": "heart_rate", "value": 82, "recorded_at": f"{day}T10:32:00+05:30", "local_date": day, "external_id": "hc-hr-1"},
        {"metric_type": "blood_pressure", "value": 124, "value2": 81, "recorded_at": f"{day}T09:00:00+05:30", "local_date": day, "external_id": "hc-bp-1"},
        {"metric_type": "spo2", "value": 98, "recorded_at": f"{day}T09:01:00+05:30", "local_date": day},
    ]


def test_health_platform_sync_is_deduplicated_and_keeps_measurement_time(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    device = client.post(f"{API}/wearables/connect", headers=headers, json={
        "provider": "health_connect", "platform": "android", "granted_metrics": ["steps", "heart_rate", "blood_pressure", "spo2", "not_a_metric"]}).json()
    assert device["granted_metrics"] == ["blood_pressure", "heart_rate", "spo2", "steps"] and device["platform"] == "android"

    first = client.post(f"{API}/wearables/{device['id']}/sync", headers=headers, json={"samples": _health_samples()}).json()
    assert (first["imported"], first["duplicates"], first["up_to_date"]) == (4, 0, False)
    again = client.post(f"{API}/wearables/{device['id']}/sync", headers=headers, json={"samples": _health_samples()}).json()
    assert (again["imported"], again["updated"], again["duplicates"], again["up_to_date"]) == (0, 0, 4, True)

    # The day's running total grows: the same row is refreshed, never duplicated.
    later = _health_samples()
    later[0] = {**later[0], "value": 7420, "recorded_at": "2026-09-20T21:00:00+05:30"}
    refreshed = client.post(f"{API}/wearables/{device['id']}/sync", headers=headers, json={"samples": later}).json()
    assert (refreshed["imported"], refreshed["updated"], refreshed["duplicates"]) == (0, 1, 3)
    steps = client.get(f"{API}/patients/{pid}/trends?metric=steps&range=custom&start=2026-09-20&end=2026-09-20", headers=headers).json()["points"]
    assert [(p["value"], p["sources"]) for p in steps] == [(7420, ["health_platform"])] and steps[0]["last_synced_at"]

    from app import db as db_module
    from app.models import LifestyleMetric
    with db_module.SessionLocal() as db:
        hr = db.query(LifestyleMetric).filter_by(metric_type="heart_rate").one()
        # Measurement time is the watch's, not the sync time.
        assert hr.recorded_at.replace(tzinfo=None).isoformat() == "2026-09-20T05:02:00" and hr.synced_at is not None
        assert hr.source == "health_platform" and str(hr.local_date) == "2026-09-20"
        assert db.query(LifestyleMetric).count() == 4


def test_health_sync_skips_ungranted_future_and_implausible_values(env):
    client, _, _ = env
    headers, _ = register_patient(client)
    device = client.post(f"{API}/wearables/connect", headers=headers, json={"provider": "health_connect", "granted_metrics": ["steps"]}).json()
    samples = _health_samples() + [
        {"metric_type": "steps", "value": 900, "recorded_at": "2099-01-01T00:00:00Z", "local_date": "2099-01-01", "daily_total": True},
        {"metric_type": "steps", "value": -5, "recorded_at": "2026-09-19T12:00:00Z", "local_date": "2026-09-19", "daily_total": True},
    ]
    result = client.post(f"{API}/wearables/{device['id']}/sync", headers=headers, json={"samples": samples}).json()
    assert (result["imported"], result["skipped"]) == (1, 5)
    # An empty read is "already up to date", not a failure.
    empty = client.post(f"{API}/wearables/{device['id']}/sync", headers=headers, json={"samples": []}).json()
    assert empty["up_to_date"] is True and empty["device"]["status"] == "connected"


def test_synced_health_data_follows_patient_authorization(env):
    client, _, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    pid = patient["patient_id"]
    device = client.post(f"{API}/wearables/connect", headers=patient_headers, json={"provider": "health_connect"}).json()
    client.post(f"{API}/wearables/{device['id']}/sync", headers=patient_headers, json={"samples": _health_samples()})
    assert client.get(f"{API}/patients/{pid}/lifestyle/overview", headers=doc).status_code == 403
    grant_access(client, doc, patient_headers, patient)
    overview = client.get(f"{API}/patients/{pid}/lifestyle/overview", headers=doc).json()
    assert overview["devices"][0]["provider"] == "health_connect" and overview["devices"][0]["last_synced_at"]
    # Disconnecting keeps the history.
    client.post(f"{API}/wearables/{device['id']}/disconnect", headers=patient_headers)
    points = client.get(f"{API}/patients/{pid}/trends?metric=heart_rate&range=custom&start=2026-09-20&end=2026-09-20", headers=doc).json()["points"]
    assert points and points[0]["value"] == 82
    assert client.post(f"{API}/wearables/{device['id']}/sync", headers=patient_headers, json={"samples": []}).status_code == 409

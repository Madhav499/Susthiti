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
    assert gemini.requests[0]["contents"][0]["parts"][1]["inlineData"]["mimeType"] == "application/pdf"
    assert "Do not invent values" in gemini.requests[0]["systemInstruction"]["parts"][0]["text"]
    assert client.get(f"{API}/reports/{report['id']}/summary", headers=headers).json()["summary"]["id"] == r.json()["summary"]["id"]
    pdf = client.get(f"{API}/ai-summaries/{r.json()['summary']['id']}/pdf", headers=headers)
    assert pdf.status_code == 200 and pdf.content.startswith(b"%PDF")
    assert "SUSTHITI_Individual_Report_Summary_" in pdf.headers["content-disposition"]


def test_ai_invalid_response_then_retry(env):
    client, _, gemini = env
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    gemini.queue_raw(httpx.Response(200, json={"candidates": [{"content": {"parts": [{"text": "not json at all"}]}}]}))
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 502 and r.json()["detail"]["code"] == "ai_invalid_response"
    # original report still available
    assert client.get(f"{API}/reports/{report['id']}/file", headers=headers).status_code == 200
    gemini.queue_json({"summary": "ok"})
    assert client.post(f"{API}/reports/{report['id']}/summary", headers=headers).status_code == 201


def test_ai_api_failure(env, monkeypatch):
    client, _, gemini = env
    from app.services.ai import gemini as gemini_module

    monkeypatch.setattr(gemini_module.time, "sleep", lambda seconds: None)
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
    gemini.queue_json({"patient_overview": "45-year-old male.", "items_to_discuss": ["Sleep"]})
    r = client.post(f"{API}/patients/{patient['patient_id']}/patient-summary", headers=doctor_headers)
    assert r.status_code == 201, r.text
    assert r.json()["summary"]["generated_by_role"] == "doctor"


def test_ai_not_configured(env):
    client, _, _ = env
    from app.services.ai import services as ai_services
    from app.services.ai.gemini import GeminiClient

    ai_services.set_ai_client(GeminiClient(api_key=""))
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
    sent = gemini.requests[-1]["contents"][0]["parts"][0]["text"]
    assert "peanuts" in sent and "avoid high-sodium food" in sent
    assert "allergies" in gemini.requests[-1]["systemInstruction"]["parts"][0]["text"]


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
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    patient_headers, patient = register_patient(client)
    grant_access(client, doc, patient_headers, patient)
    client.post(f"{API}/patients/{patient['patient_id']}/side-effects", headers=patient_headers, json={"description": "Dizziness", "severity": "moderate", "occurred_at": "2026-09-20T08:00:00Z"})
    dash = client.get(f"{API}/doctor/dashboard", headers=doc).json()
    assert dash["metrics"]["patients"] == 1 and dash["metrics"]["open_side_effects"] == 1
    assert dash["needs_attention"][0]["patient_code"] == patient["patient_code"]
    admin_dash = client.get(f"{API}/admin/dashboard", headers=admin).json()
    assert admin_dash["metrics"]["total_doctors"] == 1


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

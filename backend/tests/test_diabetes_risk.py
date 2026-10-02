"""Future diabetes risk (API v4) integration: health data -> features -> API -> stored assessment.

The model is the FakeRiskAPI test double, which follows API v4's contract. Tests check what
SUSTHITI sends (and never sends), where each value came from, and the assessment lifecycle.
"""

import json
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import httpx
import pytest

from app import db as db_module
from app.models import AISummary, DiabetesAssessment, DiabetesRiskAssessment, Patient
from app.services.diabetes_risk.features import FEATURES
from app.services.health_data.snapshot import build_snapshot
from tests.conftest import grant_access, make_admin, make_doctor, model_inputs, register_patient, upload

API = "/api/v1"
SAMPLES = Path(__file__).resolve().parents[2] / "diabetes_risk_api"
TODAY = date.today()


def age_of(dob: date) -> int:
    return TODAY.year - dob.year - ((TODAY.month, TODAY.day) < (dob.month, dob.day))


def profile(client, headers, pid, **values):
    r = client.put(f"{API}/patients/{pid}/health-profile", headers=headers, json={"values": values})
    assert r.status_code == 200, r.text
    return r.json()


def confirm(client, headers, report_id, **values):
    r = client.put(f"{API}/reports/{report_id}/values", headers=headers, json={"values": values})
    assert r.status_code == 200, r.text
    return r.json()


def assess(client, headers, pid, expect=201):
    r = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    assert r.status_code == expect, r.text
    return r.json()


def new_report(client, headers, pid, report_date=None, category="hba1c"):
    r = upload(client, headers, pid, category=category, report_date=(report_date or TODAY - timedelta(days=10)).isoformat())
    assert r.status_code == 201, r.text
    return r.json()["id"]


def set_dob(pid, dob: date, gender="Female"):
    with db_module.SessionLocal() as db:
        p = db.get(Patient, pid)
        p.date_of_birth, p.gender = dob, gender
        db.commit()


def sync_health(client, headers, samples):
    device = client.post(f"{API}/wearables/connect", headers=headers, json={
        "provider": "health_connect", "platform": "android",
        "granted_metrics": ["steps", "sleep", "heart_rate", "blood_pressure", "oxygen_saturation", "spo2", "activity"]}).json()
    r = client.post(f"{API}/wearables/{device['id']}/sync", headers=headers, json={"samples": samples})
    assert r.status_code == 200, r.text
    return r.json()


def daily(metric, value, days, start_offset=1):
    out = []
    for i in range(start_offset, start_offset + days):
        day = TODAY - timedelta(days=i)
        out.append({"metric_type": metric, "value": value, "recorded_at": f"{day}T21:00:00+00:00", "started_at": f"{day}T00:00:00+00:00",
                    "local_date": day.isoformat(), "daily_total": True})
    return out


# ---------- What is sent ----------

def test_profile_only_patient_is_assessed_without_inventing_anything(env):  # TEST 1, 2, 12, 13
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    body = assess(client, headers, pid)
    # Only genuinely known values: age from date of birth and sex. No report, no "No" for unknowns.
    assert ml.calls == [{"age": age_of(date(1990, 1, 1)), "sex": "Male"}]
    a = body["assessment"]
    assert a["report_available"] is False and a["report_fields_present"] == [] and a["prediction_basis"] == "symptoms_and_risk_factors_only"
    assert a["risk_percent"] == 43.21 and a["risk_category"] == "Moderate" and a["model_version"] == "4.0.0"
    assert "no report data" in a["warning"]
    missing = {m["feature"] for m in a["data_used"]["missing"]}
    assert {"hba1c", "sleep_hours", "hypertension", "polyuria"} <= missing and "bmi" not in missing


@pytest.mark.parametrize("analyte, payload, field, sent", [
    ("hba1c", {"value": 6.1, "unit": "%"}, "hba1c", 6.1),  # TEST 3
    ("fasting_glucose", {"value": 110, "unit": "mg/dL"}, "fasting_glucose", 110.0),  # TEST 4
    ("random_glucose", {"value": 8.0, "unit": "mmol/L"}, "random_glucose", 144.1),  # TEST 5 (converted to mg/dL)
    ("ogtt_2h", {"value": 160, "unit": "mg/dL"}, "previous_ogtt_2h", 160.0),  # TEST 6
    ("diabetes_classification", {"text_value": "prediabetes"}, "previous_health_report_status", "Prediabetes"),  # TEST 7
])
def test_one_report_value_makes_the_report_available(env, analyte, payload, field, sent):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    confirm(client, headers, new_report(client, headers, pid), **{analyte: payload})
    a = assess(client, headers, pid)["assessment"]
    assert ml.calls[0][field] == sent
    assert a["report_available"] is True and a["report_fields_present"] == [field]
    assert a["prediction_basis"] == "symptoms_and_available_health_report"
    report_items = next(g for g in a["data_used"]["groups"] if g["key"] == "report")["items"]
    assert report_items[0]["feature"] == field and report_items[0]["report_code"]


def test_previous_prediabetes_is_history_not_a_report(env):  # TEST 8
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    profile(client, headers, pid, previous_prediabetes=True)
    a = assess(client, headers, pid)["assessment"]
    assert ml.calls[0]["previous_prediabetes"] == 1
    assert not any(f in ml.calls[0] for f in ("hba1c", "fasting_glucose", "random_glucose", "previous_ogtt_2h", "previous_health_report_status"))
    assert a["report_available"] is False
    history = next(g for g in a["data_used"]["groups"] if g["key"] == "medical_history")["items"]
    assert history[0]["feature"] == "previous_prediabetes"


def _equivalent_patient(client, with_report: bool):
    """Patient data equivalent to the API's test_request_*.json samples (golden tests)."""
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    dob = date(TODAY.year - 75, 1, 1) if (TODAY.month, TODAY.day) >= (1, 1) else date(TODAY.year - 76, 1, 1)
    set_dob(pid, dob, "Female")
    profile(client, headers, pid, height_cm=178, weight_kg=65, family_history_diabetes=True, previous_prediabetes=False,
            physical_activity_level="low", diet_quality="poor", hypertension=False, high_cholesterol=False,
            polyuria=False, polydipsia=True, unexplained_weight_loss=False, polyphagia=True)
    if with_report:
        confirm(client, headers, new_report(client, headers, pid), hba1c={"value": 5.5, "unit": "%"}, fasting_glucose={"value": 100, "unit": "mg/dL"},
                random_glucose={"value": 125, "unit": "mg/dL"}, ogtt_2h={"value": 95, "unit": "mg/dL"}, diabetes_classification={"text_value": "normal"})
    return headers, pid


@pytest.mark.parametrize("with_report, sample", [(True, "test_request_report.json"), (False, "test_request_no_report.json")])
def test_golden_requests_match_the_api_samples(env, with_report, sample):  # PART 67, TEST 9
    client, ml, _ = env
    headers, pid = _equivalent_patient(client, with_report)
    a = assess(client, headers, pid)["assessment"]
    expected = json.loads((SAMPLES / sample).read_text())["data"]
    assert ml.calls[0] == expected
    assert a["report_fields_present"] == (["hba1c", "fasting_glucose", "random_glucose", "previous_ogtt_2h", "previous_health_report_status"] if with_report else [])


def test_not_sure_is_never_sent_as_no(env):  # PART 19
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    profile(client, headers, pid, hypertension=None, polyuria=None, smoking_status="never")
    a = assess(client, headers, pid)["assessment"]
    assert "hypertension" not in ml.calls[0] and "polyuria" not in ml.calls[0] and ml.calls[0]["smoking_status"] == "Never"
    reasons = {m["feature"]: m["reason"] for m in a["data_used"]["missing"]}
    assert reasons["hypertension"] == 'Answered "not sure"'


def test_invalid_values_are_refused_before_the_model(env):  # TEST 17
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    for values in ({"smoking_status": "Available"}, {"smoking_status": "Current"}, {"hypertension": "yes"}, {"weight_kg": -3}, {"not_a_field": 1}):
        assert client.put(f"{API}/patients/{pid}/health-profile", headers=headers, json={"values": values}).status_code == 422, values
    report_id = new_report(client, headers, pid)
    for values in ({"diabetes_classification": {"text_value": "Available"}}, {"hba1c": {"value": 60, "unit": "mmol/mol"}}, {"hba1c": {"value": 45, "unit": "%"}}):
        assert client.put(f"{API}/reports/{report_id}/values", headers=headers, json={"values": values}).status_code == 422, values
    assess(client, headers, pid)
    assert set(ml.calls[0]) == {"age", "sex"}


def test_only_model_features_are_sent_never_identity(env):  # PART 70, 71
    client, ml, _ = env
    headers, pid = _equivalent_patient(client, with_report=True)
    assess(client, headers, pid)
    assert set(ml.calls[0]) <= set(FEATURES)
    sent = json.dumps(ml.calls[0])
    assert "Madhav" not in sent and "@" not in sent and "SUS-P" not in sent


# ---------- Wearables and lifestyle ----------

def test_wearable_sleep_and_steps_feed_only_their_model_fields(env):  # TEST 10, 11
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    profile(client, headers, pid, physical_activity_level="low")  # self-report: used only without enough steps
    samples = daily("sleep", 420, 5) + daily("steps", 12000, 8)
    samples += [{"metric_type": "heart_rate", "value": 88, "recorded_at": f"{TODAY - timedelta(days=1)}T10:00:00+00:00", "external_id": "hr-1"},
                {"metric_type": "spo2", "value": 97, "recorded_at": f"{TODAY - timedelta(days=1)}T10:05:00+00:00", "external_id": "o2-1"},
                {"metric_type": "blood_pressure", "value": 150, "value2": 95, "recorded_at": f"{TODAY - timedelta(days=1)}T10:06:00+00:00", "external_id": "bp-1"}]
    sync_health(client, headers, samples)
    a = assess(client, headers, pid)["assessment"]
    sent = ml.calls[0]
    assert sent["sleep_hours"] == 7.0 and sent["physical_activity_level"] == "High"
    # Heart rate, SpO2 and blood pressure have no model field: nothing is derived from them.
    assert "hypertension" not in sent and set(sent) == {"age", "sex", "sleep_hours", "physical_activity_level"}
    wearable = next(g for g in a["data_used"]["groups"] if g["key"] == "wearable")["items"]
    assert {i["feature"] for i in wearable} == {"sleep_hours", "physical_activity_level"}
    assert "12,000 steps a day" in next(i for i in wearable if i["feature"] == "physical_activity_level")["detail"]


def test_too_little_wearable_data_falls_back_or_stays_missing(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    profile(client, headers, pid, physical_activity_level="moderate")
    sync_health(client, headers, daily("sleep", 420, 2) + daily("steps", 12000, 3))
    a = assess(client, headers, pid)["assessment"]
    assert "sleep_hours" not in ml.calls[0]
    assert ml.calls[0]["physical_activity_level"] == "Moderate"  # self-reported fallback
    reasons = {m["feature"]: m["reason"] for m in a["data_used"]["missing"]}
    assert "2 of the last 14 nights" in reasons["sleep_hours"]


def test_stale_wearable_data_is_not_used(env):  # PART 30
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    sync_health(client, headers, daily("sleep", 420, 5, start_offset=20))
    assess(client, headers, pid)
    assert "sleep_hours" not in ml.calls[0]


def test_demo_data_is_never_health_data(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    device = client.post(f"{API}/wearables/connect", headers=headers, json={"provider": "demo"}).json()
    client.post(f"{API}/wearables/{device['id']}/sync", headers=headers)
    assess(client, headers, pid)
    assert "sleep_hours" not in ml.calls[0] and "physical_activity_level" not in ml.calls[0]


def test_recent_questionnaire_symptoms_are_reused_not_reasked(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    with db_module.SessionLocal() as db:
        user_id = db.get(Patient, pid).user_id
        db.add(DiabetesAssessment(assessment_code="DA-TEST1", patient_id=pid, assessed_at=datetime.now(timezone.utc) - timedelta(days=10),
                                  model_version="old", inputs=model_inputs(Polyuria="Yes", Polyphagia="No"), prediction="Negative",
                                  performed_by_user_id=user_id, performed_by_role="patient"))
        db.commit()
    a = assess(client, headers, pid)["assessment"]
    assert ml.calls[0]["polyuria"] == 1 and ml.calls[0]["polyphagia"] == 0
    symptoms = next(g for g in a["data_used"]["groups"] if g["key"] == "symptoms")["items"]
    assert all("questionnaire" in i["detail"] for i in symptoms)
    profile(client, headers, pid, polyuria=False)  # a newer health-profile answer wins
    assess(client, headers, pid)
    assert ml.calls[1]["polyuria"] == 0


# ---------- Reports ----------

def test_newest_report_wins_and_older_values_stay_in_history(env):  # PART 15, 16
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    older = new_report(client, headers, pid, TODAY - timedelta(days=250))
    newer = new_report(client, headers, pid, TODAY - timedelta(days=8))
    confirm(client, headers, newer, hba1c={"value": 6.1, "unit": "%"})
    confirm(client, headers, older, hba1c={"value": 5.4, "unit": "%"})  # entered later, but older report
    assess(client, headers, pid)
    assert ml.calls[0]["hba1c"] == 6.1
    with db_module.SessionLocal() as db:
        snap = build_snapshot(db, db.get(Patient, pid))
    assert snap.get("lab.hba1c").value == 6.1 and snap.history["lab.hba1c"].value == 5.4


def test_reports_older_than_two_years_are_not_current(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    confirm(client, headers, new_report(client, headers, pid, TODAY - timedelta(days=800)), hba1c={"value": 6.4, "unit": "%"})
    a = assess(client, headers, pid)["assessment"]
    assert "hba1c" not in ml.calls[0] and a["report_available"] is False
    assert "older than 2 years" in {m["feature"]: m["reason"] for m in a["data_used"]["missing"]}["hba1c"]


def test_ai_summary_values_are_only_strict_suggestions_until_confirmed(env):  # PART 14, 88
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report_id = new_report(client, headers, pid)
    with db_module.SessionLocal() as db:
        user_id = db.get(Patient, pid).user_id
        db.add(AISummary(patient_id=pid, kind="individual_report", subject_id=report_id, source_ids=[report_id], source_fingerprint="x",
                         provider="test", model="test", generated_by_user_id=user_id, generated_by_role="patient", content={"summary": "s", "relevant_values": [
                             {"name": "HbA1c", "value": "6.1", "unit": "%"},
                             {"name": "Fasting Blood Sugar", "value": "6.2", "unit": "mmol/L"},
                             {"name": "Glucose", "value": "110", "unit": "mg/dL"},  # which glucose? ambiguous
                             {"name": "PPBS", "value": "160", "unit": "mg/dL"},  # post-meal is not an OGTT
                             {"name": "OGTT 2 hr", "value": "<140", "unit": "mg/dL"},  # not one number
                             {"name": "HbA1c", "value": "43", "unit": "mmol/mol"},  # unit we don't convert: ignored
                             {"name": "RBS", "value": "140", "unit": "mg/dL"},
                             {"name": "Random blood sugar", "value": "9.0", "unit": "mmol/L"},  # conflicts with 140 mg/dL
                         ]}))
        db.commit()
    values = client.get(f"{API}/reports/{report_id}/values", headers=headers).json()
    # Random glucose appears with two different values: ambiguous, so neither is suggested.
    assert {(s["analyte"], s["value"]) for s in values["suggestions"]} == {("hba1c", 6.1), ("fasting_glucose", 111.7)}
    assess(client, headers, pid)
    assert "fasting_glucose" not in ml.calls[0]  # a suggestion is not health data
    confirm(client, headers, report_id, fasting_glucose={"value": 6.2, "unit": "mmol/L", "origin": "ai_suggestion"})
    a = assess(client, headers, pid)["assessment"]
    assert ml.calls[1]["fasting_glucose"] == 111.7
    item = next(g for g in a["data_used"]["groups"] if g["key"] == "report")["items"][0]
    assert "suggested by the AI report summary and confirmed" in item["detail"]


def test_report_value_corrections_are_appended(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report_id = new_report(client, headers, pid)
    confirm(client, headers, report_id, hba1c={"value": 6.1, "unit": "%"})
    corrected = confirm(client, headers, report_id, hba1c={"value": 6.3, "unit": "%"})
    assert [v["value"] for v in corrected["values"]] == [6.3]
    assert confirm(client, headers, report_id, hba1c=None)["values"] == []
    with db_module.SessionLocal() as db:
        from app.models import ReportValue
        assert db.query(ReportValue).filter_by(report_id=report_id).count() == 3  # nothing deleted
    assess(client, headers, pid)
    assert "hba1c" not in ml.calls[0]


# ---------- Lifecycle ----------

def test_unchanged_data_reuses_the_assessment_without_calling_the_model(env):  # PART 62, 89
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    first = assess(client, headers, pid)
    again = assess(client, headers, pid, expect=200)
    assert again["created"] is False and again["assessment"]["id"] == first["assessment"]["id"]
    assert len(ml.calls) == 1 and ml.health_calls == 1
    assert client.get(f"{API}/patients/{pid}/diabetes-risk", headers=headers).json()["stale"] is False
    assert len(ml.calls) == 1  # reading the status never calls the model


def test_new_report_marks_the_assessment_stale_and_history_is_immutable(env):  # TEST 14, PART 42-44
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    first = assess(client, headers, pid)["assessment"]
    confirm(client, headers, new_report(client, headers, pid), hba1c={"value": 6.1, "unit": "%"})
    status = client.get(f"{API}/patients/{pid}/diabetes-risk", headers=headers).json()
    assert status["stale"] is True and status["stale_reasons"] == ["New or changed values from your medical reports"]
    assert status["current_data"]["groups"][-1]["key"] in ("report", "profile", "medical_history")
    second = assess(client, headers, pid)["assessment"]
    assert second["id"] != first["id"] and second["report_available"] is True
    old = client.get(f"{API}/diabetes-risk/{first['id']}", headers=headers).json()
    assert old["input_features"] == {"age": age_of(date(1990, 1, 1)), "sex": "Male"} and old["report_available"] is False
    history = client.get(f"{API}/patients/{pid}/diabetes-risk/history", headers=headers).json()
    assert history["total"] == 2 and history["items"][0]["id"] == second["id"]


def test_small_lifestyle_changes_do_not_mark_it_stale(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    profile(client, headers, pid, weight_kg=70.2)
    assess(client, headers, pid)
    profile(client, headers, pid, weight_kg=70.4)  # same at 1 kg precision
    assert client.get(f"{API}/patients/{pid}/diabetes-risk", headers=headers).json()["stale"] is False
    profile(client, headers, pid, weight_kg=74)
    status = client.get(f"{API}/patients/{pid}/diabetes-risk", headers=headers).json()
    assert status["stale"] is True and status["stale_reasons"] == ["Your profile or body measurements changed"]


def test_unavailable_model_keeps_the_last_valid_assessment(env):  # TEST 15, 16
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    first = assess(client, headers, pid)["assessment"]
    profile(client, headers, pid, hypertension=True)
    ml.fail = True
    r = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    assert r.status_code == 503 and r.json()["detail"]["code"] == "model_service_unavailable"
    assert ml.calls == [ml.calls[0]]  # never predicted against an unhealthy service
    status = client.get(f"{API}/patients/{pid}/diabetes-risk", headers=headers).json()
    assert status["latest"]["id"] == first["id"] and status["stale"] is True and status["history_total"] == 1


@pytest.mark.parametrize("response, status, code", [
    (httpx.ConnectError("refused"), 503, "model_service_unavailable"),
    (httpx.ReadTimeout("slow"), 504, "model_service_timeout"),
    (httpx.Response(500, json={"detail": "boom"}), 502, "model_inference_failed"),
    (httpx.Response(200, json={"success": True, "future_diabetes_risk_percent": 140}), 502, "model_inference_failed"),
    (httpx.Response(200, text="not json"), 502, "model_inference_failed"),
    (httpx.Response(422, json={"detail": ["sex must be one of: Female, Male"]}), 422, "validation_error"),
])
def test_failures_are_calm_and_store_nothing(env, response, status, code):  # PART 39, 64
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    ml.respond_with = response
    r = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    assert (r.status_code, r.json()["detail"]["code"]) == (status, code)
    assert "Traceback" not in r.text and "refused" not in r.text
    assert client.get(f"{API}/patients/{pid}/diabetes-risk/history", headers=headers).json()["total"] == 0


def test_inconsistent_or_unsupported_responses_are_rejected(env):  # PART 40, 64
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    ok = {"success": True, "future_diabetes_risk_percent": 10.0, "risk_category": "Low", "prediction": 0, "prediction_label": "Lower-risk pattern",
          "prediction_basis": "symptoms_and_available_health_report", "report_available": True, "report_fields_present": ["hba1c"],
          "bmi": None, "model_version": "4.0.0", "warning": "w"}
    ml.respond_with = httpx.Response(200, json=ok)  # claims a report that was never sent
    assert client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers).status_code == 502
    ml.respond_with = None
    ml.health_body = {"status": "ok", "model_loaded": True, "model_version": "5.0.0"}
    r = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    assert r.status_code == 502 and r.json()["detail"]["code"] == "model_version_unsupported"
    ml.health_body = {"status": "ok", "model_loaded": False, "model_version": "4.0.0"}
    assert client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers).status_code == 503
    assert ml.calls == []


# ---------- Access, dashboard, timeline ----------

def test_doctor_with_access_can_view_and_refresh_others_cannot(env):  # PART 49
    client, ml, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    other, _ = make_doctor(client, admin, "other@example.org", "Other Doctor")
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    a = assess(client, headers, pid)["assessment"]
    assert client.get(f"{API}/patients/{pid}/diabetes-risk", headers=doc).status_code == 403
    assert client.get(f"{API}/diabetes-risk/{a['id']}", headers=doc).status_code == 403
    grant_access(client, doc, headers, patient)
    assert client.get(f"{API}/diabetes-risk/{a['id']}", headers=doc).json()["risk_percent"] == 43.21
    profile(client, doc, pid, hypertension=True)  # recorded as the doctor's entry
    refreshed = assess(client, doc, pid)["assessment"]
    assert refreshed["performed_by_role"] == "doctor"
    detail = next(g for g in refreshed["data_used"]["groups"] if g["key"] == "medical_history")["items"][0]
    assert "entered by your doctor" in detail["detail"]
    assert client.get(f"{API}/patients/{pid}/diabetes-risk", headers=other).status_code == 403
    assert client.get(f"{API}/patients/{pid}/diabetes-risk", headers=admin).status_code == 200


def test_dashboard_timeline_and_admin_views_show_the_risk(env):  # PART 74
    client, ml, _ = env
    admin = make_admin(client)
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assert client.get(f"{API}/patients/{pid}/dashboard", headers=headers).json()["diabetes_risk"] == {"latest": None, "stale": False, "stale_reasons": []}
    a = assess(client, headers, pid)["assessment"]
    dash = client.get(f"{API}/patients/{pid}/dashboard", headers=headers).json()["diabetes_risk"]
    assert dash["latest"]["id"] == a["id"] and dash["latest"]["risk_category"] == "Moderate" and dash["stale"] is False
    events = client.get(f"{API}/patients/{pid}/timeline", headers=headers).json()["items"]
    risk_event = next(e for e in events if e["type"] == "diabetes_risk")
    assert "43.21% model-estimated risk (Moderate)" in risk_event["subtitle"]
    profile_view = client.get(f"{API}/admin/patients/{pid}", headers=admin).json()
    assert profile_view["latest_assessment"]["risk_category"] == "Moderate" and profile_view["counts"]["assessments"] == 1


def test_health_profile_keeps_every_answer(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    profile(client, headers, pid, weight_kg=72)
    out = profile(client, headers, pid, weight_kg=70.5)
    weight = next(f for f in out["fields"] if f["key"] == "weight_kg")
    assert weight["value"] == 70.5 and weight["recorded_by_role"] == "patient" and weight["answered"] is True
    from app.models import HealthFact
    with db_module.SessionLocal() as db:
        assert db.query(HealthFact).filter_by(patient_id=pid, field="weight_kg").count() == 2
    assert next(f for f in out["fields"] if f["key"] == "pcos")["applies_to"] == "Female"


def test_expired_answers_are_not_used(env):  # PART 30-31 freshness
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    profile(client, headers, pid, stress_level="high", polyuria=True, hypertension=True)
    from app.models import HealthFact
    with db_module.SessionLocal() as db:
        for fact in db.query(HealthFact).filter_by(patient_id=pid):
            fact.recorded_at = datetime.now(timezone.utc) - timedelta(days=120)
        db.commit()
    assess(client, headers, pid)
    sent = ml.calls[0]
    assert "stress_level" not in sent and "polyuria" not in sent  # 90-day answers expired
    assert sent["hypertension"] == 1  # medical history does not expire

"""Heart disease risk screening integration: health data + manual form -> features -> API ->
stored assessment. The model is the FakeHeartRiskAPI test double (see conftest.py), which
follows the supplied susthiti-heart-v3 API's real contract. Tests check what SUSTHITI sends
(and never sends/invents), where each value came from, and the assessment lifecycle -- mirrors
tests/test_diabetes_risk.py's structure for the sibling diabetes feature.
"""

import httpx
import pytest
from datetime import date, timedelta

from app import db as db_module
from app.models import HeartRiskAssessment, Patient
from app.services.heart_risk.features import FEATURES
from tests.conftest import grant_access, make_admin, make_doctor, register_patient, upload

API = "/api/v1"
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


def assess(client, headers, pid, fields=None, force=False, expect=201):
    body = {"fields": fields} if fields is not None else {}
    url = f"{API}/patients/{pid}/heart-risk" + ("?force=true" if force else "")
    r = client.post(url, headers=headers, json=body)
    assert r.status_code == expect, r.text
    return r.json()


def new_report(client, headers, pid, report_date=None, category="blood_report"):
    r = upload(client, headers, pid, category=category, report_date=(report_date or TODAY - timedelta(days=10)).isoformat())
    assert r.status_code == 201, r.text
    return r.json()["id"]


def set_dob(pid, dob: date, gender="Male"):
    with db_module.SessionLocal() as db:
        p = db.get(Patient, pid)
        p.date_of_birth, p.gender = dob, gender
        db.commit()


# ---------- Service contract (direct, no DB) ----------

def test_health_model_info_predict_endpoints(heart_ml):
    """Smoke-tests the FakeHeartRiskAPI double itself follows the real API's shape."""
    import httpx as _httpx

    base = "http://heart.test"
    with _httpx.Client(transport=_httpx.MockTransport(heart_ml.handler)) as c:
        health = c.get(f"{base}/health").json()
        assert health == {"status": "ok", "model_version": "susthiti-heart-v3"}
        info = c.get(f"{base}/model-info").json()
        assert len(info["features"]) == 59 and info["threshold"] == 0.3275
        pred = c.post(f"{base}/predict", json={"data": {"age": 50}}).json()
        assert set(pred) == {"model_version", "prediction", "prediction_label", "probability", "probability_percent", "risk_level", "decision_threshold", "warnings", "disclaimer"}


# ---------- What is sent ----------

def test_profile_only_patient_is_screened_without_inventing_anything(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    body = assess(client, headers, pid)
    # Only genuinely known values: age and sex from the profile. No symptoms, no "No" for unknowns.
    assert heart_ml.calls == [{"age": age_of(date(1990, 1, 1)), "sex": "Male"}]
    a = body["assessment"]
    assert a["report_available"] is False and a["prediction"] == 0
    missing = {m["feature"] for m in a["data_used"]["missing"]}
    assert {"hba1c", "chest_pain", "diabetes", "resting_ecg"} <= missing and "bmi" not in missing


def test_lab_values_confirmed_from_a_report_are_reused(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    confirm(client, headers, new_report(client, headers, pid), total_cholesterol={"value": 220, "unit": "mg/dL"},
            ldl={"value": 140, "unit": "mg/dL"}, troponin={"value": 0.02, "unit": "ng/mL"})
    a = assess(client, headers, pid)["assessment"]
    sent = heart_ml.calls[0]
    assert sent["total_cholesterol"] == 220.0 and sent["ldl"] == 140.0 and sent["troponin"] == 0.02
    assert a["report_available"] is True and set(a["report_fields_present"]) == {"total_cholesterol", "ldl", "troponin"}
    report_items = {i["feature"] for i in next(g for g in a["data_used"]["groups"] if g["key"] == "report")["items"]}
    assert report_items == {"total_cholesterol", "ldl", "troponin"}


def test_medical_history_fields_are_reused_and_distinct_from_each_other(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    profile(client, headers, pid, previous_heart_attack=True, stroke_history=False, hypertension=True)
    a = assess(client, headers, pid)["assessment"]
    sent = heart_ml.calls[0]
    assert sent["previous_heart_attack"] == 1 and sent["stroke_history"] == 0 and sent["hypertension"] == 1
    assert "previous_heart_disease" not in sent and "kidney_disease" not in sent  # never answered, never defaulted
    history = {i["feature"] for i in next(g for g in a["data_used"]["groups"] if g["key"] == "medical_history")["items"]}
    assert history == {"previous_heart_attack", "stroke_history", "hypertension"}


def test_diabetes_field_is_never_inferred_from_the_diabetes_screening(env, heart_ml):
    """The heart model's own `diabetes` yes/no field must never be filled in from the
    diabetes risk assessment's score -- it has no safe existing source."""
    client, ml, gemini = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    a = assess(client, headers, pid)["assessment"]
    assert "diabetes" not in heart_ml.calls[0]
    reasons = {m["feature"]: m["reason"] for m in a["data_used"]["missing"]}
    assert "heart assessment form" in reasons["diabetes"]


def test_invalid_manual_values_are_refused_before_the_model(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    r = client.post(f"{API}/patients/{pid}/heart-risk", headers=headers, json={"fields": {"chest_pain_type": "typical_angina", "age": 45}})
    assert r.status_code == 201, r.text
    assert heart_ml.calls[0]["chest_pain_type"] == "Typical_Angina"


def test_only_model_features_are_sent_never_identity(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assess(client, headers, pid, fields={"chest_pain": True, "resting_ecg": "normal_variant"})
    assert set(heart_ml.calls[0]) <= set(FEATURES)
    import json as _json
    sent = _json.dumps(heart_ml.calls[0])
    assert "Madhav" not in sent and "@" not in sent and "SUS-P" not in sent


# ---------- Manual assessment form ----------

def test_manual_form_fields_overlay_the_snapshot_and_are_never_persisted_as_profile(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    fields = {
        "chest_pain": True, "chest_pain_type": "typical_angina", "shortness_of_breath": False,
        "resting_ecg": "st_t_abnormality", "ecg_abnormality": True, "ejection_fraction": 55,
    }
    a = assess(client, headers, pid, fields=fields)["assessment"]
    sent = heart_ml.calls[0]
    assert sent["chest_pain"] == 1 and sent["chest_pain_type"] == "Typical_Angina" and sent["shortness_of_breath"] == 0
    assert sent["ecg_abnormality"] == 1 and sent["ejection_fraction"] == 55.0
    symptoms = {i["feature"]: i["source"] for i in next(g for g in a["data_used"]["groups"] if g["key"] == "symptoms")["items"]}
    assert symptoms["chest_pain"] == "manual_entry"
    # Never written back into the durable health profile.
    profile_fields = client.get(f"{API}/patients/{pid}/health-profile", headers=headers).json()["fields"]
    assert not any(f["key"] == "chest_pain" for f in profile_fields)


def test_every_form_submission_creates_a_new_assessment_even_if_identical(env, heart_ml):
    """Unlike a bare refresh, a questionnaire submission is never deduplicated: the patient
    explicitly answered fresh questions."""
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    fields = {"chest_pain": False}
    first = assess(client, headers, pid, fields=fields)["assessment"]
    second = assess(client, headers, pid, fields=fields)["assessment"]
    assert first["id"] != second["id"]
    assert len(heart_ml.calls) == 2
    history = client.get(f"{API}/patients/{pid}/heart-risk/history", headers=headers).json()
    assert history["total"] == 2


# ---------- Lifecycle (bare refresh) ----------

def test_bare_refresh_reuses_the_assessment_without_calling_the_model(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    first = assess(client, headers, pid)
    again = assess(client, headers, pid, expect=200)
    assert again["created"] is False and again["assessment"]["id"] == first["assessment"]["id"]
    assert len(heart_ml.calls) == 1 and heart_ml.health_calls == 1
    assert client.get(f"{API}/patients/{pid}/heart-risk", headers=headers).json()["stale"] is False


def test_new_report_marks_the_assessment_stale_and_history_is_immutable(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    first = assess(client, headers, pid)["assessment"]
    confirm(client, headers, new_report(client, headers, pid), total_cholesterol={"value": 220, "unit": "mg/dL"})
    status = client.get(f"{API}/patients/{pid}/heart-risk", headers=headers).json()
    assert status["stale"] is True and status["stale_reasons"] == ["New or changed values from your medical reports"]
    second = assess(client, headers, pid)["assessment"]
    assert second["id"] != first["id"] and second["report_available"] is True
    old = client.get(f"{API}/heart-risk/{first['id']}", headers=headers).json()
    assert old["report_available"] is False  # history untouched
    history = client.get(f"{API}/patients/{pid}/heart-risk/history", headers=headers).json()
    assert history["total"] == 2 and history["items"][0]["id"] == second["id"]


def test_multiple_historical_assessments_are_all_kept(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    heart_ml.probability_percent = 20.0
    low = assess(client, headers, pid, fields={"chest_pain": False})["assessment"]
    heart_ml.probability_percent = 80.0
    high = assess(client, headers, pid, fields={"chest_pain": True})["assessment"]
    assert low["risk_level"] == "low" and high["risk_level"] == "high"
    history = client.get(f"{API}/patients/{pid}/heart-risk/history", headers=headers).json()
    assert history["total"] == 2
    assert [i["id"] for i in history["items"]] == [high["id"], low["id"]]  # newest first


def test_unavailable_model_keeps_the_last_valid_assessment(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    first = assess(client, headers, pid)["assessment"]
    heart_ml.fail = True
    r = client.post(f"{API}/patients/{pid}/heart-risk", headers=headers, json={"fields": {"chest_pain": True}})
    assert r.status_code == 503 and r.json()["detail"]["code"] == "model_service_unavailable"
    status = client.get(f"{API}/patients/{pid}/heart-risk", headers=headers).json()
    assert status["latest"]["id"] == first["id"] and status["history_total"] == 1


@pytest.mark.parametrize("response, status, code", [
    (httpx.ConnectError("refused"), 503, "model_service_unavailable"),
    (httpx.ReadTimeout("slow"), 504, "model_service_timeout"),
    (httpx.Response(500, json={"detail": "boom"}), 502, "model_inference_failed"),
    (httpx.Response(200, json={"prediction": 2}), 502, "model_inference_failed"),
    (httpx.Response(200, text="not json"), 502, "model_inference_failed"),
    (httpx.Response(422, json={"detail": {"errors": ["sex must be 0/1 or yes/no"]}}), 422, "validation_error"),
])
def test_failures_are_calm_and_store_nothing(env, heart_ml, response, status, code):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    heart_ml.respond_with = response
    r = client.post(f"{API}/patients/{pid}/heart-risk", headers=headers, json={})
    assert (r.status_code, r.json()["detail"]["code"]) == (status, code)
    assert "Traceback" not in r.text
    assert client.get(f"{API}/patients/{pid}/heart-risk/history", headers=headers).json()["total"] == 0


def test_unsupported_model_version_is_rejected(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    heart_ml.model_version = "susthiti-heart-v4"
    r = client.post(f"{API}/patients/{pid}/heart-risk", headers=headers, json={})
    assert r.status_code == 502 and r.json()["detail"]["code"] == "model_version_unsupported"
    assert heart_ml.calls == []


# ---------- Access, dashboard, timeline (shared with diabetes) ----------

def test_doctor_with_access_can_view_and_refresh_others_cannot(env, heart_ml):
    client, ml, _ = env
    admin = make_admin(client)
    doc, _ = make_doctor(client, admin)
    other, _ = make_doctor(client, admin, "other-heart@example.org", "Other Doctor")
    headers, patient = register_patient(client, email="heart-patient@example.org")
    pid = patient["patient_id"]
    a = assess(client, headers, pid)["assessment"]
    assert client.get(f"{API}/patients/{pid}/heart-risk", headers=doc).status_code == 403
    assert client.get(f"{API}/heart-risk/{a['id']}", headers=doc).status_code == 403
    grant_access(client, doc, headers, patient)
    assert client.get(f"{API}/heart-risk/{a['id']}", headers=doc).json()["probability_percent"] == a["probability_percent"]
    refreshed = assess(client, doc, pid, fields={"chest_pain": False})["assessment"]
    assert refreshed["id"] != a["id"]
    assert client.get(f"{API}/patients/{pid}/heart-risk", headers=other).status_code == 403
    assert client.get(f"{API}/patients/{pid}/heart-risk", headers=admin).status_code == 200


def test_dashboard_and_timeline_show_the_heart_screening_alongside_diabetes(env, heart_ml):
    client, ml, _ = env
    headers, patient = register_patient(client, email="heart-dash@example.org")
    pid = patient["patient_id"]
    dash = client.get(f"{API}/patients/{pid}/dashboard", headers=headers).json()
    assert dash["heart_risk"] == {"latest": None, "stale": False, "stale_reasons": []}
    assert dash["diabetes_risk"] == {"latest": None, "stale": False, "stale_reasons": []}  # diabetes unaffected
    a = assess(client, headers, pid)["assessment"]
    dash = client.get(f"{API}/patients/{pid}/dashboard", headers=headers).json()
    assert dash["heart_risk"]["latest"]["id"] == a["id"]
    events = client.get(f"{API}/patients/{pid}/timeline", headers=headers).json()["items"]
    heart_event = next(e for e in events if e["type"] == "heart_risk")
    assert "model score" in heart_event["subtitle"]
    assert client.get(f"{API}/patients/{pid}/timeline?type=assessments", headers=headers).json()["items"]


def test_admin_profile_shows_heart_assessment_counts(env, heart_ml):
    client, ml, _ = env
    admin = make_admin(client, email="heart-admin@example.org")
    headers, patient = register_patient(client, email="heart-admin-patient@example.org")
    pid = patient["patient_id"]
    assess(client, headers, pid)
    profile_view = client.get(f"{API}/admin/patients/{pid}", headers=admin).json()
    assert profile_view["latest_heart_assessment"]["risk_level"] in ("low", "moderate", "high")
    assert profile_view["counts"]["heart_assessments"] == 1


def test_diabetes_assessment_still_works_unaffected_by_heart(env, heart_ml):
    """Guards against any cross-wiring between the two sibling risk features."""
    client, ml, _ = env
    headers, patient = register_patient(client, email="both-risks@example.org")
    pid = patient["patient_id"]
    d = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    assert d.status_code == 201
    h = assess(client, headers, pid)
    assert h["assessment"]["id"] != d.json()["assessment"]["id"]
    assert len(ml.calls) == 1 and len(heart_ml.calls) == 1

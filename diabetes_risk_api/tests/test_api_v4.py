"""Contract tests for the supplied SUSTHITI API v4 (main.py and the model are used unmodified).

They pin the behaviour SUSTHITI relies on, above all the report-detection rule: only the five
report fields make report_available true; previous_prediabetes never does.
"""

import json
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import main  # noqa: E402

REPORT_FIELDS = ["hba1c", "fasting_glucose", "random_glucose", "previous_ogtt_2h", "previous_health_report_status"]


@pytest.fixture(scope="module")
def client():
    return TestClient(main.app)


def sample(name: str) -> dict:
    return json.loads((ROOT / name).read_text())["data"]


def predict(client, data: dict) -> dict:
    response = client.post("/predict", json={"data": data})
    assert response.status_code == 200, response.text
    return response.json()


def test_health_reports_model_and_version(client):
    body = client.get("/health").json()
    assert body["status"] == "ok" and body["model_loaded"] is True and body["model_version"] == "4.0.0"


def test_profile_only_patient_gets_a_prediction(client):  # TEST 1
    body = predict(client, {"age": 30, "sex": "Male"})
    assert body["success"] is True and 0 <= body["future_diabetes_risk_percent"] <= 100
    assert body["risk_category"] in {"Low", "Moderate", "High"}


def test_no_report_is_symptoms_and_risk_factors_only(client):  # TEST 2
    body = predict(client, sample("test_request_no_report.json"))
    assert body["report_available"] is False and body["report_fields_present"] == []
    assert body["prediction_basis"] == "symptoms_and_risk_factors_only"
    assert "not fully trusted" in body["warning"]


@pytest.mark.parametrize("field, value", [
    ("hba1c", 6.1),  # TEST 3
    ("fasting_glucose", 110),  # TEST 4
    ("random_glucose", 150),  # TEST 5
    ("previous_ogtt_2h", 160),  # TEST 6
    ("previous_health_report_status", "Prediabetes"),  # TEST 7
])
def test_any_single_report_field_makes_a_report_available(client, field, value):
    body = predict(client, {**sample("test_request_no_report.json"), field: value})
    assert body["report_available"] is True and body["report_fields_present"] == [field]
    assert body["prediction_basis"] == "symptoms_and_available_health_report"


def test_previous_prediabetes_is_not_report_evidence(client):  # TEST 8
    body = predict(client, {**sample("test_request_no_report.json"), "previous_prediabetes": 1})
    assert body["report_available"] is False and body["report_fields_present"] == []


def test_complete_report_uses_every_report_field(client):  # TEST 9
    body = predict(client, sample("test_request_report.json"))
    assert body["report_fields_present"] == REPORT_FIELDS
    assert body["model_version"] == "4.0.0" and body["bmi"] == pytest.approx(20.52)


def test_null_report_fields_do_not_count(client):
    body = predict(client, {**sample("test_request_no_report.json"), **{f: None for f in REPORT_FIELDS}})
    assert body["report_available"] is False


def test_available_is_not_a_report_status(client):  # TEST 17
    response = client.post("/predict", json={"data": {**sample("test_request_no_report.json"), "previous_health_report_status": "Available"}})
    assert response.status_code == 422


def test_risk_bands_follow_the_api(client):
    body = predict(client, sample("test_request_report.json"))
    assert body["risk_thresholds"] == {"low": "0-40%", "moderate": ">40-65%", "high": ">65%"}
    risk = body["future_diabetes_risk_percent"]
    expected = "Low" if risk <= 40 else "Moderate" if risk <= 65 else "High"
    assert body["risk_category"] == expected

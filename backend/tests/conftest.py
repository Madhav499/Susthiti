import json
import os
import tempfile

os.environ.setdefault("REMINDERS_ENABLED", "false")
# Tests sign in many times from one client; the limiter has its own test that switches it on.
os.environ.setdefault("AUTH_RATE_LIMIT_ENABLED", "false")
# AI reading of report values has its own tests; elsewhere uploads must not queue AI calls.
os.environ.setdefault("AI_READ_REPORT_VALUES", "false")
os.environ.setdefault("DEV_EXPOSE_RESET_TOKEN", "true")
os.environ.setdefault("OPENROUTER_API_KEY", "test-key-not-real")

import httpx  # noqa: E402
import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import db as db_module  # noqa: E402
from app.db import Base  # noqa: E402
from app.services import storage  # noqa: E402
from app.services.diabetes_risk import client as risk_client  # noqa: E402
from app.services.ai import services as ai_services  # noqa: E402
from app.services.ai.openrouter import OpenRouterClient  # noqa: E402

PDF_BYTES = b"%PDF-1.4\n% TEST FIXTURE ONLY\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"


class FakeRiskAPI:
    """TEST double of the SUSTHITI Diabetes Risk API v4. Follows its contract (report detection,
    risk bands, the 50% prediction, categorical validation); only the risk number is fake."""

    REPORT_FIELDS = ["hba1c", "fasting_glucose", "random_glucose", "previous_ogtt_2h", "previous_health_report_status"]
    CATEGORICAL = {
        "sex": {"Male", "Female"}, "physical_activity_level": {"High", "Moderate", "Low"}, "diet_quality": {"Good", "Average", "Poor"},
        "sugary_drink_frequency": {"Never/Rarely", "1-3_per_week", "4-6_per_week", "Daily"}, "smoking_status": {"Never", "Former", "Current"},
        "alcohol_frequency": {"Never", "Occasionally", "Weekly", "Frequent"}, "stress_level": {"Low", "Moderate", "High"},
        "previous_health_report_status": {"Normal", "Prediabetes", "Diabetes"},
    }

    def __init__(self):
        self.calls = []
        self.health_calls = 0
        self.fail = False
        self.risk = 43.21
        self.health_body = {"status": "ok", "model_loaded": True, "model_version": "4.0.0"}
        # Set to an httpx.Response or an exception to simulate other /predict failures.
        self.respond_with = None

    def handler(self, request: httpx.Request) -> httpx.Response:
        if request.url.path == "/health":
            self.health_calls += 1
            return httpx.Response(503) if self.fail else httpx.Response(200, json=self.health_body)
        if self.fail:
            return httpx.Response(503, json={"detail": "unavailable"})
        if isinstance(self.respond_with, Exception):
            raise self.respond_with
        if self.respond_with is not None:
            return self.respond_with
        data = json.loads(request.content)["data"]
        self.calls.append(data)
        errors = [f"{k} must be one of: ..." for k, allowed in self.CATEGORICAL.items() if data.get(k) is not None and data[k] not in allowed]
        if errors:
            return httpx.Response(422, json={"detail": errors})
        present = [f for f in self.REPORT_FIELDS if data.get(f) is not None]
        risk = self.risk
        category = "Low" if risk <= 40 else "Moderate" if risk <= 65 else "High"
        bmi = data.get("bmi")
        if bmi is None and data.get("height_cm") and data.get("weight_kg"):
            bmi = round(data["weight_kg"] / (data["height_cm"] / 100) ** 2, 2)
        return httpx.Response(200, json={
            "success": True, "future_diabetes_risk_percent": risk, "risk_category": category,
            "risk_thresholds": {"low": "0-40%", "moderate": ">40-65%", "high": ">65%"},
            "prediction": 1 if risk >= 50 else 0, "prediction_label": "Higher-risk pattern" if risk >= 50 else "Lower-risk pattern",
            "prediction_threshold": "50% for binary model target",
            "prediction_basis": "symptoms_and_available_health_report" if present else "symptoms_and_risk_factors_only",
            "report_available": bool(present), "report_fields_present": present, "bmi": bmi, "model_version": "4.0.0",
            "warning": "TEST warning: not a medical diagnosis." if present else "TEST warning: no report data; not fully trusted.",
        })


class FakeOpenRouter:
    """TEST double for OpenRouter's chat-completions endpoint."""

    def __init__(self):
        self.responses: list = []
        self.requests = []

    def queue_json(self, obj):
        self.responses.append(httpx.Response(200, json={"choices": [{"message": {"content": json.dumps(obj)}}]}))

    def queue_raw(self, response: httpx.Response):
        self.responses.append(response)

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(json.loads(request.content))
        if not self.responses:
            return httpx.Response(500)
        return self.responses.pop(0)


@pytest.fixture()
def env(tmp_path):
    db_module.configure_engine(f"sqlite:///{tmp_path}/test.db")
    Base.metadata.create_all(db_module.engine)
    storage.set_storage(storage.LocalFileStorage(str(tmp_path / "files")))
    ml = FakeRiskAPI()
    risk_client.set_risk_client(risk_client.DiabetesRiskApiV4Client("http://ml.test", transport=httpx.MockTransport(ml.handler)))
    gemini = FakeOpenRouter()
    ai_services.set_ai_client(OpenRouterClient(api_key="test", model="test-model", transport=httpx.MockTransport(gemini.handler)))
    from app.main import app

    with TestClient(app) as client:
        yield client, ml, gemini
    risk_client.set_risk_client(None)
    ai_services.set_ai_client(None)


def register_patient(client, name="Madhav Test", email="patient@example.org"):
    r = client.post("/api/v1/auth/register", json={"full_name": name, "email": email, "password": "Password1", "date_of_birth": "1990-01-01", "gender": "Male"})
    assert r.status_code == 201, r.text
    data = r.json()
    return {"Authorization": f"Bearer {data['access_token']}"}, data["user"]


def make_admin(client, email="admin@example.org"):
    from app.models import User
    from app.security import hash_password

    with db_module.SessionLocal() as db:
        db.add(User(email=email, password_hash=hash_password("Password1"), role="admin", full_name="Admin"))
        db.commit()
    r = client.post("/api/v1/auth/login", json={"email": email, "password": "Password1"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def make_doctor(client, admin_headers, email="doctor@example.org", name="Asha Rao"):
    r = client.post("/api/v1/admin/doctors", headers=admin_headers, json={"full_name": name, "email": email, "temporary_password": "Password1", "license_number": "MCI-TEST-001"})
    assert r.status_code == 201, r.text
    login = client.post("/api/v1/auth/login", json={"email": email, "password": "Password1"})
    return {"Authorization": f"Bearer {login.json()['access_token']}"}, r.json()


def grant_access(client, doctor_headers, patient_headers, patient_user):
    r = client.post("/api/v1/access-requests", headers=doctor_headers, json={"patient_name": patient_user["full_name"], "patient_code": patient_user["patient_code"]})
    assert r.status_code == 201, r.text
    r = client.post(f"/api/v1/access-requests/{r.json()['id']}/approve", headers=patient_headers)
    assert r.status_code == 200, r.text


def upload(client, headers, patient_id, category="hba1c", report_date="2026-01-05", data=PDF_BYTES, filename="hba1c_jan.pdf"):
    return client.post(
        f"/api/v1/patients/{patient_id}/reports", headers=headers,
        data={"category": category, "report_date": report_date, "description": "Lab report"},
        files={"file": (filename, data, "application/pdf")},
    )


YES_NO = ["Polyuria", "Polydipsia", "sudden weight loss", "weakness", "Polyphagia", "Genital thrush", "visual blurring", "Itching",
          "Irritability", "delayed healing", "partial paresis", "muscle stiffness", "Alopecia", "Obesity"]


def model_inputs(**overrides):
    inputs = {"Age": 45, "Gender": "Male", **{k: "No" for k in YES_NO}}
    inputs.update(overrides)
    return inputs

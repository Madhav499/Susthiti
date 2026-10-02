"""Timeline filters, BMI, birthdays, doctor licence, and forced re-assessment."""

from datetime import date, datetime, timedelta, timezone

from app import db as db_module
from app.models import Notification, Patient
from app.services.health_data.body import bmi_of, is_birthday
from app.services.reminders import run_reminders
from tests.conftest import make_admin, register_patient, upload

API = "/api/v1"


def test_every_timeline_filter_shows_its_own_events(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    upload(client, headers, pid)
    client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    types = lambda f: {e["type"] for e in client.get(f"{API}/patients/{pid}/timeline", headers=headers, params={"type": f}).json()["items"]}  # noqa: E731
    assert types("all") == {"report", "diabetes_risk"}
    assert types("reports") == {"report"} and types("report") == {"report"}  # the app's old names still work
    assert types("assessments") == {"diabetes_risk"} and types("assessment") == {"diabetes_risk"}
    assert types("prescriptions") == set() and types("appointments") == set()
    assert client.get(f"{API}/patients/{pid}/timeline", headers=headers, params={"type": "nonsense"}).status_code == 422


def test_bmi_is_calculated_and_shown_on_the_profile(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assert client.get(f"{API}/patients/me", headers=headers).json()["body"]["bmi"] is None
    client.put(f"{API}/patients/{pid}/health-profile", headers=headers, json={"values": {"height_cm": 170, "weight_kg": 72.5}})
    body = client.get(f"{API}/patients/me", headers=headers).json()["body"]
    assert (body["height_cm"], body["weight_kg"], body["bmi"]) == (170, 72.5, 25.1)
    assert client.get(f"{API}/patients/{pid}/health-profile", headers=headers).json()["body"]["bmi"] == 25.1
    assert bmi_of(None, 70) is None and bmi_of(180, 81) == 25.0


def test_doctor_licence_is_required(env):
    client, _, _ = env
    admin = make_admin(client)
    base = {"full_name": "Dr Who", "email": "who@example.org", "temporary_password": "Password1"}
    assert client.post(f"{API}/admin/doctors", headers=admin, json=base).status_code == 422
    assert client.post(f"{API}/admin/doctors", headers=admin, json={**base, "license_number": "  "}).status_code == 422
    created = client.post(f"{API}/admin/doctors", headers=admin, json={**base, "license_number": " MCI-778 "})
    assert created.status_code == 201 and created.json()["license_number"] == "MCI-778"


def test_birthdays_are_detected_and_wished_once_a_year(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    assert is_birthday(date(2000, 2, 29), date(2026, 2, 28)) and not is_birthday(date(2000, 2, 29), date(2028, 2, 28))
    from app.services.health_data.body import local_today
    today = local_today()
    with db_module.SessionLocal() as db:
        db.get(Patient, pid).date_of_birth = date(1990, today.month, min(today.day, 28))
        db.commit()
    if today.day <= 28:
        assert client.get(f"{API}/patients/{pid}/dashboard", headers=headers).json()["patient"]["is_birthday"] is True
        with db_module.SessionLocal() as db:
            run_reminders(db, datetime.now(timezone.utc))
            run_reminders(db, datetime.now(timezone.utc))
            wishes = db.query(Notification).filter_by(type="birthday").all()
        assert len(wishes) == 1 and wishes[0].title.startswith("Happy birthday")
    with db_module.SessionLocal() as db:
        db.get(Patient, pid).date_of_birth = today - timedelta(days=40)
        db.commit()
    assert client.get(f"{API}/patients/{pid}/dashboard", headers=headers).json()["patient"]["is_birthday"] is False


def test_age_follows_the_date_of_birth(env):
    client, _, _ = env
    headers, patient = register_patient(client)  # born 1 Jan 1990
    today = date.today()
    expected = today.year - 1990 - ((today.month, today.day) < (1, 1))
    assert client.get(f"{API}/patients/me", headers=headers).json()["age"] == expected


def test_a_requested_reassessment_is_always_a_new_record(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    first = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers).json()["assessment"]
    same = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
    assert same.status_code == 200 and same.json()["assessment"]["id"] == first["id"]
    forced = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers, params={"force": "true"})
    assert forced.status_code == 201 and forced.json()["assessment"]["id"] != first["id"]
    assert len(ml.calls) == 2
    assert client.get(f"{API}/patients/{pid}/diabetes-risk/history", headers=headers).json()["total"] == 2

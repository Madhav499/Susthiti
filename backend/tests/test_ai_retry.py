"""Bounded retry/backoff for transient Gemini failures (services/ai/gemini.py). Backoff
sleeps are monkeypatched away so these tests run fast and deterministically.
"""

import httpx

from tests.conftest import register_patient, upload

API = "/api/v1"


def _no_sleep(monkeypatch):
    from app.services.ai import gemini as gemini_module

    monkeypatch.setattr(gemini_module.time, "sleep", lambda seconds: None)


def test_a_transient_503_is_retried_and_then_succeeds(env, monkeypatch):
    client, _, gemini = env
    _no_sleep(monkeypatch)
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    gemini.queue_raw(httpx.Response(503))
    gemini.queue_json({"summary": "Recovered after a retry."})
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201, r.text
    assert r.json()["summary"]["content"]["summary"] == "Recovered after a retry."
    assert len(gemini.requests) == 2


def test_a_429_honors_retry_after(env, monkeypatch):
    client, _, gemini = env
    from app.services.ai import gemini as gemini_module

    sleeps: list[float] = []
    monkeypatch.setattr(gemini_module.time, "sleep", lambda seconds: sleeps.append(seconds))
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    gemini.queue_raw(httpx.Response(429, headers={"Retry-After": "7"}))
    gemini.queue_json({"summary": "Recovered after the rate limit cleared."})
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201, r.text
    assert sleeps == [7.0]


def test_a_non_retryable_status_fails_immediately(env, monkeypatch):
    client, _, gemini = env
    from app.services.ai import gemini as gemini_module

    sleeps: list[float] = []
    monkeypatch.setattr(gemini_module.time, "sleep", lambda seconds: sleeps.append(seconds))
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"]).json()
    gemini.queue_raw(httpx.Response(400))
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 503 and r.json()["detail"]["code"] == "ai_service_unavailable"
    assert len(gemini.requests) == 1  # no retry for a non-retryable status
    assert sleeps == []

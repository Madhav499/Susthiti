import pytest

from app.config import get_settings
from app.services.rate_limit import RateLimiter, limiter
from tests.conftest import register_patient, upload

# `heart_ml` (FakeHeartRiskAPI double) is a fixture defined in tests/conftest.py and picked up
# automatically -- no import needed, same as `env`.

API = "/api/v1"


def test_rate_limiter_allows_the_limit_then_blocks_until_the_window_passes():
    rl = RateLimiter()
    assert all(rl.hit("login:1.2.3.4", 3, 60, now=t) is None for t in (0, 1, 2))
    retry = rl.hit("login:1.2.3.4", 3, 60, now=3)
    assert retry == pytest.approx(57)
    assert rl.hit("login:5.6.7.8", 3, 60, now=3) is None  # other clients are unaffected
    assert rl.hit("login:1.2.3.4", 3, 60, now=60.5) is None  # the oldest attempt has expired


def test_sign_in_is_throttled_per_client_when_enabled(env, monkeypatch):
    client, _, _ = env
    register_patient(client, email="throttle@example.org")
    monkeypatch.setattr(get_settings(), "auth_rate_limit_enabled", True)
    limiter.reset()
    try:
        wrong = {"email": "throttle@example.org", "password": "WrongPassword1"}
        statuses = [client.post(f"{API}/auth/login", json=wrong).status_code for _ in range(20)]
        assert set(statuses) == {401}
        blocked = client.post(f"{API}/auth/login", json={"email": "throttle@example.org", "password": "Password1"})
        assert blocked.status_code == 429
        assert blocked.json()["detail"]["code"] == "rate_limited"
        assert int(blocked.headers["retry-after"]) > 0
    finally:
        limiter.reset()


def test_ai_endpoints_require_authentication_before_any_rate_limit_applies(env):
    """The per-user limiter depends on an authenticated caller; confirms it doesn't change -- or
    accidentally bypass -- the existing 401 for a signed-out caller on any of the newly
    protected endpoints."""
    client, _, _ = env
    assert client.post(f"{API}/reports/does-not-exist/summary").status_code == 401
    assert client.post(f"{API}/patients/does-not-exist/diabetes-risk").status_code == 401
    assert client.post(f"{API}/patients/does-not-exist/heart-risk", json={}).status_code == 401


def test_health_endpoint_is_never_rate_limited(env, monkeypatch):
    """/health is a liveness/internal-reachability check (it calls out to the ML services'
    own /health, not the rate-limited patient-facing endpoints) -- confirmed by calling it far
    more times than any of the new AI/risk limits would allow."""
    client, _, _ = env
    monkeypatch.setattr(get_settings(), "auth_rate_limit_enabled", True)
    limiter.reset()
    try:
        statuses = {client.get("/health").status_code for _ in range(25)}
        assert statuses == {200}
    finally:
        limiter.reset()


def test_ai_generate_allows_the_limit_then_blocks_per_user(env, monkeypatch):
    """The shared ai-generate budget (10 per 10 minutes) covers every AI-generating endpoint for
    one user, since they all spend the same OpenRouter quota. Calls 2-10 here reuse the stored
    summary rather than calling the AI again (see test_ai_caching.py), but still count against
    the budget -- the limiter guards the endpoint, not just the AI call itself."""
    client, _, gemini = env
    headers, patient = register_patient(client, email="ai-limit@example.org")
    report = upload(client, headers, patient["patient_id"]).json()
    monkeypatch.setattr(get_settings(), "auth_rate_limit_enabled", True)
    limiter.reset()
    try:
        gemini.queue_json({"summary": "First pass."})
        first = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
        assert first.status_code == 201, first.text
        for _ in range(9):
            again = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
            assert again.status_code == 200, again.text
        blocked = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
        assert blocked.status_code == 429
        detail = blocked.json()["detail"]
        assert detail["code"] == "rate_limited"
        assert "traceback" not in str(detail).lower() and "exception" not in str(detail).lower()
        assert int(blocked.headers["retry-after"]) > 0
    finally:
        limiter.reset()


def test_ai_generate_limit_is_isolated_per_user(env, monkeypatch):
    """One patient exhausting their AI budget never affects another patient's."""
    client, _, gemini = env
    a_headers, a_patient = register_patient(client, email="ai-isolation-a@example.org")
    b_headers, b_patient = register_patient(client, email="ai-isolation-b@example.org")
    a_report = upload(client, a_headers, a_patient["patient_id"]).json()
    b_report = upload(client, b_headers, b_patient["patient_id"]).json()
    monkeypatch.setattr(get_settings(), "auth_rate_limit_enabled", True)
    limiter.reset()
    try:
        gemini.queue_json({"summary": "A's summary."})
        for _ in range(10):
            r = client.post(f"{API}/reports/{a_report['id']}/summary", headers=a_headers)
            assert r.status_code in (200, 201), r.text
        assert client.post(f"{API}/reports/{a_report['id']}/summary", headers=a_headers).status_code == 429

        gemini.queue_json({"summary": "B's summary."})
        still_fine = client.post(f"{API}/reports/{b_report['id']}/summary", headers=b_headers)
        assert still_fine.status_code == 201, still_fine.text
    finally:
        limiter.reset()


def test_diabetes_risk_predict_allows_the_limit_then_blocks(env, monkeypatch):
    client, _, _ = env
    headers, patient = register_patient(client, email="diabetes-risk-limit@example.org")
    pid = patient["patient_id"]
    monkeypatch.setattr(get_settings(), "auth_rate_limit_enabled", True)
    limiter.reset()
    try:
        for _ in range(6):
            r = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
            assert r.status_code in (200, 201), r.text
        blocked = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers)
        assert blocked.status_code == 429
        assert int(blocked.headers["retry-after"]) > 0
    finally:
        limiter.reset()


def test_heart_risk_predict_allows_the_limit_then_blocks(env, heart_ml, monkeypatch):
    client, _, _ = env
    headers, patient = register_patient(client, email="heart-risk-limit@example.org")
    pid = patient["patient_id"]
    monkeypatch.setattr(get_settings(), "auth_rate_limit_enabled", True)
    limiter.reset()
    try:
        for _ in range(6):
            r = client.post(f"{API}/patients/{pid}/heart-risk", headers=headers, json={})
            assert r.status_code in (200, 201), r.text
        blocked = client.post(f"{API}/patients/{pid}/heart-risk", headers=headers, json={})
        assert blocked.status_code == 429
        assert int(blocked.headers["retry-after"]) > 0
    finally:
        limiter.reset()


def test_diabetes_and_heart_risk_budgets_are_independent(env, heart_ml, monkeypatch):
    """Exhausting the diabetes-risk budget must not block heart-risk, and vice versa -- they're
    separate metered services with separate buckets."""
    client, _, _ = env
    headers, patient = register_patient(client, email="risk-independent@example.org")
    pid = patient["patient_id"]
    monkeypatch.setattr(get_settings(), "auth_rate_limit_enabled", True)
    limiter.reset()
    try:
        for _ in range(6):
            assert client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers).status_code in (200, 201)
        assert client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers).status_code == 429
        still_fine = client.post(f"{API}/patients/{pid}/heart-risk", headers=headers, json={})
        assert still_fine.status_code in (200, 201), still_fine.text
    finally:
        limiter.reset()


@pytest.fixture()
def production_env(monkeypatch):
    monkeypatch.setenv("SUSTHITI_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "x" * 48)
    monkeypatch.setenv("DEV_EXPOSE_RESET_TOKEN", "false")
    monkeypatch.setenv("ENABLE_DEMO_WEARABLE", "false")
    monkeypatch.setenv("AUTH_RATE_LIMIT_ENABLED", "true")
    return monkeypatch


def test_production_settings_accept_a_safe_configuration(production_env):
    settings = get_settings.__wrapped__()
    assert settings.is_production and not settings.enable_demo_wearable and settings.auth_rate_limit_enabled


@pytest.mark.parametrize("name, value, message", [
    ("JWT_SECRET", "dev-only-insecure-secret-change-me", "JWT_SECRET"),
    ("DEV_EXPOSE_RESET_TOKEN", "true", "DEV_EXPOSE_RESET_TOKEN"),
    ("ENABLE_DEMO_WEARABLE", "true", "ENABLE_DEMO_WEARABLE"),
    ("AUTH_RATE_LIMIT_ENABLED", "false", "AUTH_RATE_LIMIT_ENABLED"),
])
def test_production_refuses_unsafe_settings(production_env, name, value, message):
    production_env.setenv(name, value)
    with pytest.raises(RuntimeError, match=message):
        get_settings.__wrapped__()

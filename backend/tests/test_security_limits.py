import pytest

from app.config import get_settings
from app.services.rate_limit import RateLimiter, limiter
from tests.conftest import register_patient

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

"""Comprehensive tests for the password reset email flow and Resend delivery layer."""

import json
import logging
from datetime import datetime, timedelta, timezone

import httpx
import pytest

from app import db as db_module
from app.config import get_settings
from app.models import PasswordResetToken, User
from app.security import hash_token
from app.services.email import EmailDeliveryResult, EmailService, get_email_service, set_email_service
from app.services.rate_limit import limiter
from tests.conftest import register_patient

API = "/api/v1"


class FakeResendAPI:
    """Test double for the Resend HTTP API."""

    def __init__(self):
        self.calls = []
        self.status_code = 200
        self.response_body = {"id": "resend-test-msg-001"}
        self.error_to_raise = None

    def handler(self, request: httpx.Request) -> httpx.Response:
        if self.error_to_raise is not None:
            raise self.error_to_raise
        body = json.loads(request.content.decode("utf-8")) if request.content else {}
        self.calls.append({
            "url": str(request.url),
            "headers": dict(request.headers),
            "body": body,
        })
        return httpx.Response(self.status_code, json=self.response_body)


@pytest.fixture()
def fake_resend():
    fake = FakeResendAPI()
    service = EmailService(
        api_key="re_mock_test_key_12345",
        from_email="noreply@example.org",
        from_name="SUSTHITI",
        timeout=5.0,
        transport=httpx.MockTransport(fake.handler),
    )
    set_email_service(service)
    yield fake
    set_email_service(None)


# 1. Forgot password for existing user
def test_forgot_password_existing_user(env, fake_resend):
    client, _, _ = env
    register_patient(client, email="existing@example.org")

    r = client.post(f"{API}/auth/forgot-password", json={"email": "existing@example.org"})
    assert r.status_code == 200
    data = r.json()
    assert data["message"] == "If an account exists for this email, password reset instructions have been sent."

    with db_module.SessionLocal() as db:
        user = db.query(User).filter(User.email == "existing@example.org").first()
        assert user is not None
        token_record = db.query(PasswordResetToken).filter(PasswordResetToken.user_id == user.id).first()
        assert token_record is not None
        assert token_record.used_at is None
        # Verify 30-minute expiry
        now = datetime.now(timezone.utc)
        record_expiry = token_record.expires_at.replace(tzinfo=timezone.utc) if token_record.expires_at.tzinfo is None else token_record.expires_at
        assert record_expiry > now
        assert record_expiry <= now + timedelta(minutes=31)


# 2. Forgot password for unknown email
def test_forgot_password_unknown_email(env, fake_resend):
    client, _, _ = env

    r = client.post(f"{API}/auth/forgot-password", json={"email": "unknown-ghost@example.org"})
    assert r.status_code == 200
    assert r.json() == {"message": "If an account exists for this email, password reset instructions have been sent."}

    # No email should be sent for unknown users
    assert len(fake_resend.calls) == 0

    with db_module.SessionLocal() as db:
        assert db.query(PasswordResetToken).count() == 0


# 3. Email service called for valid user
def test_email_service_called_for_valid_user(env, fake_resend):
    client, _, _ = env
    register_patient(client, name="Aarav Sharma", email="aarav@example.org")

    r = client.post(f"{API}/auth/forgot-password", json={"email": "aarav@example.org"})
    assert r.status_code == 200

    assert len(fake_resend.calls) == 1
    call = fake_resend.calls[0]
    assert call["url"] == "https://api.resend.com/emails"
    assert call["headers"]["authorization"] == "Bearer re_mock_test_key_12345"
    assert call["body"]["from"] == "SUSTHITI <noreply@example.org>"
    assert call["body"]["to"] == ["aarav@example.org"]
    assert call["body"]["subject"] == "SUSTHITI Password Reset"

    text = call["body"]["text"]
    assert "Hello Aarav Sharma," in text
    assert "We received a request to reset your SUSTHITI account password." in text
    assert "Your password reset code is:" in text
    assert "This code expires after 30 minutes." in text
    assert "If you did not request this password reset, you can safely ignore this email." in text
    assert "For security, do not share this code with anyone." in text
    assert "Regards,\nSUSTHITI Team" in text

    html = call["body"]["html"]
    assert "Hello Aarav Sharma," in html
    assert "SUSTHITI Password Reset" in html
    assert "This code expires after 30 minutes." in html


# 4. Raw reset token is not returned in production response
def test_raw_reset_token_not_returned_in_production(env, fake_resend, monkeypatch):
    client, _, _ = env
    register_patient(client, email="produser@example.org")

    # In production, DEV_EXPOSE_RESET_TOKEN is False
    monkeypatch.setattr(get_settings(), "dev_expose_reset_token", False)

    r = client.post(f"{API}/auth/forgot-password", json={"email": "produser@example.org"})
    assert r.status_code == 200
    data = r.json()
    assert "dev_reset_token" not in data
    assert list(data.keys()) == ["message"]


# 5. Raw reset token and API key are not logged
def test_raw_reset_token_and_api_key_never_logged(env, fake_resend, caplog):
    client, _, _ = env
    register_patient(client, email="secretlog@example.org")

    caplog.set_level(logging.DEBUG)
    client.post(f"{API}/auth/forgot-password", json={"email": "secretlog@example.org"})

    assert len(fake_resend.calls) == 1
    # Extract the token that was sent in the email body
    text = fake_resend.calls[0]["body"]["text"]
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    code_idx = lines.index("Your password reset code is:")
    raw_token = lines[code_idx + 1]

    assert len(raw_token) >= 32
    assert raw_token not in caplog.text
    assert "re_mock_test_key_12345" not in caplog.text


# 6. Email provider failure is handled safely
@pytest.mark.parametrize("error_kind", ["http_500", "http_422", "timeout", "network_error"])
def test_email_provider_failure_handled_safely(env, fake_resend, error_kind):
    client, _, _ = env
    register_patient(client, email=f"fail-{error_kind}@example.org")

    if error_kind == "http_500":
        fake_resend.status_code = 500
        fake_resend.response_body = {"error": "internal_server_error"}
    elif error_kind == "http_422":
        fake_resend.status_code = 422
        fake_resend.response_body = {"message": "validation error", "name": "validation_error"}
    elif error_kind == "timeout":
        fake_resend.error_to_raise = httpx.ConnectTimeout("Connection timed out")
    elif error_kind == "network_error":
        fake_resend.error_to_raise = httpx.ConnectError("Connection refused")

    # API must never crash (status 500); it returns the standard message
    r = client.post(f"{API}/auth/forgot-password", json={"email": f"fail-{error_kind}@example.org"})
    assert r.status_code == 200
    assert r.json()["message"] == "If an account exists for this email, password reset instructions have been sent."


def test_unconfigured_email_provider_handled_safely(env):
    """When Resend is unconfigured, the endpoint logs safely and does not crash."""
    client, _, _ = env
    register_patient(client, email="unconfigured@example.org")

    unconfigured_service = EmailService(api_key="", from_email="")
    set_email_service(unconfigured_service)
    try:
        r = client.post(f"{API}/auth/forgot-password", json={"email": "unconfigured@example.org"})
        assert r.status_code == 200
        assert r.json()["message"] == "If an account exists for this email, password reset instructions have been sent."
    finally:
        set_email_service(None)


# 7. Reset token remains valid after successful email send
def test_reset_token_remains_valid_after_email_send(env, fake_resend):
    client, _, _ = env
    register_patient(client, email="tokencheck@example.org")

    client.post(f"{API}/auth/forgot-password", json={"email": "tokencheck@example.org"})
    assert len(fake_resend.calls) == 1

    text = fake_resend.calls[0]["body"]["text"]
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    raw_token = lines[lines.index("Your password reset code is:") + 1]

    token_hash = hash_token(raw_token)
    with db_module.SessionLocal() as db:
        record = db.query(PasswordResetToken).filter(PasswordResetToken.token_hash == token_hash).first()
        assert record is not None
        assert record.used_at is None
        assert record.expires_at.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc)


# 8. Reset password works using the received token
def test_reset_password_works_using_received_token(env, fake_resend):
    client, _, _ = env
    headers, user = register_patient(client, email="resetuser@example.org")

    client.post(f"{API}/auth/forgot-password", json={"email": "resetuser@example.org"})
    text = fake_resend.calls[0]["body"]["text"]
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    raw_token = lines[lines.index("Your password reset code is:") + 1]

    # Reset with the code received in email
    r = client.post(f"{API}/auth/reset-password", json={"token": raw_token, "new_password": "UpdatedPassword123"})
    assert r.status_code == 200
    assert r.json()["message"] == "Your password has been updated. Please sign in."

    # Login with old password must fail
    assert client.post(f"{API}/auth/login", json={"email": "resetuser@example.org", "password": "Password1"}).status_code == 401

    # Login with new password must succeed
    login = client.post(f"{API}/auth/login", json={"email": "resetuser@example.org", "password": "UpdatedPassword123"})
    assert login.status_code == 200
    assert "access_token" in login.json()

    # Previous active sessions must have been revoked
    assert client.get(f"{API}/auth/me", headers=headers).status_code == 401


# 9. Expired token fails
def test_expired_token_fails(env, fake_resend):
    client, _, _ = env
    register_patient(client, email="expireduser@example.org")

    client.post(f"{API}/auth/forgot-password", json={"email": "expireduser@example.org"})
    text = fake_resend.calls[0]["body"]["text"]
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    raw_token = lines[lines.index("Your password reset code is:") + 1]

    # Expire the token in DB
    with db_module.SessionLocal() as db:
        record = db.query(PasswordResetToken).filter(PasswordResetToken.token_hash == hash_token(raw_token)).first()
        record.expires_at = datetime.now(timezone.utc) - timedelta(minutes=5)
        db.commit()

    r = client.post(f"{API}/auth/reset-password", json={"token": raw_token, "new_password": "NewSecretPass1"})
    assert r.status_code == 400
    assert r.json()["detail"]["code"] == "invalid_token"


# 10. Used token fails
def test_used_token_fails(env, fake_resend):
    client, _, _ = env
    register_patient(client, email="reuseduser@example.org")

    client.post(f"{API}/auth/forgot-password", json={"email": "reuseduser@example.org"})
    text = fake_resend.calls[0]["body"]["text"]
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    raw_token = lines[lines.index("Your password reset code is:") + 1]

    # First reset succeeds
    r1 = client.post(f"{API}/auth/reset-password", json={"token": raw_token, "new_password": "FirstNewPass1"})
    assert r1.status_code == 200

    # Second reset with same token fails
    r2 = client.post(f"{API}/auth/reset-password", json={"token": raw_token, "new_password": "SecondNewPass1"})
    assert r2.status_code == 400
    assert r2.json()["detail"]["code"] == "invalid_token"


# 11. Password reset rate limiting remains active
def test_password_reset_rate_limiting_remains_active(env, fake_resend, monkeypatch):
    client, _, _ = env
    register_patient(client, email="ratelimiteduser@example.org")

    monkeypatch.setattr(get_settings(), "auth_rate_limit_enabled", True)
    limiter.reset()
    try:
        # Rate limit on /forgot-password is 10 requests per hour
        for _ in range(10):
            r = client.post(f"{API}/auth/forgot-password", json={"email": "ratelimiteduser@example.org"})
            assert r.status_code == 200

        # 11th request must be throttled
        blocked = client.post(f"{API}/auth/forgot-password", json={"email": "ratelimiteduser@example.org"})
        assert blocked.status_code == 429
        assert blocked.json()["detail"]["code"] == "rate_limited"
        assert int(blocked.headers["retry-after"]) > 0
    finally:
        limiter.reset()

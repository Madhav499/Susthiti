"""Tests for FCM credential loading (backend/app/services/push.py).

FCM_SERVICE_ACCOUNT_JSON must work two ways: as a path to a key file (local development) and as
the service-account JSON document itself (Render production -- the platform has no filesystem
path to hand the app, only an environment variable's value). These tests exercise the real
firebase_admin Certificate() code path with a throwaway, test-only RSA keypair generated on the
fly -- never a real Google/Firebase credential -- so a valid document genuinely parses the same
way it would in production, not just against a mock.

None of these tests call push._app() to a *successful* completion: firebase_admin registers the
initialized app in its own global "[DEFAULT]" app registry (not something push._app's lru_cache
controls), and a second successful initialize_app() call in the same process raises "the default
app already exists." The existing test_push_handles_an_invalid_service_account_file_without_raising
in test_api.py already establishes the safe pattern this file follows: only ever exercise the
"configuration is broken, _app() returns None" path end-to-end, and test credential *parsing*
(_load_credentials) directly and in isolation for the success cases.
"""

import json
import logging

import pytest

from app.services import push


def _fake_service_account_json() -> str:
    """A syntactically valid (but entirely throwaway) service-account JSON document -- enough
    for firebase_admin's Certificate() to accept it as well-formed. Generates its own RSA
    keypair on the fly; this is never a real Google/Firebase credential."""
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_key_pem = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode()
    return json.dumps({
        "type": "service_account",
        "project_id": "susthiti-test",
        "private_key_id": "test-key-id",
        "private_key": private_key_pem,
        "client_email": "test@susthiti-test.iam.gserviceaccount.com",
        "client_id": "123456789",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/test%40susthiti-test.iam.gserviceaccount.com",
    })


# ---------- Valid inline JSON ----------

def test_valid_inline_json_is_parsed_and_builds_a_real_certificate():
    cred = push._load_credentials(_fake_service_account_json())
    assert cred.project_id == "susthiti-test"
    assert cred.service_account_email == "test@susthiti-test.iam.gserviceaccount.com"


def test_valid_inline_json_with_surrounding_whitespace_is_still_detected():
    # Render/most platforms preserve a pasted env var exactly, but a trailing newline from
    # copy-paste is common enough to be worth not breaking on.
    cred = push._load_credentials(f"  \n{_fake_service_account_json()}\n  ")
    assert cred.project_id == "susthiti-test"


# ---------- Valid file path (local development, unchanged behavior) ----------

def test_file_path_configuration_is_still_supported(tmp_path):
    key_file = tmp_path / "service-account.json"
    key_file.write_text(_fake_service_account_json())
    cred = push._load_credentials(str(key_file))
    assert cred.project_id == "susthiti-test"


# ---------- Invalid JSON / invalid path ----------

def test_invalid_inline_json_raises_and_does_not_fall_back_to_treating_it_as_a_path():
    with pytest.raises(ValueError, match="not valid JSON"):
        push._load_credentials('{"type": "service_account", this is not valid json')


def test_valid_json_missing_required_fields_is_rejected_not_silently_accepted():
    # Valid JSON, but not a usable service account -- firebase_admin's own validation must still
    # reject it; detecting "this is JSON" must not bypass that.
    with pytest.raises(ValueError):
        push._load_credentials('{"type": "service_account"}')


def test_nonexistent_file_path_raises():
    with pytest.raises(OSError):
        push._load_credentials("C:/definitely/does/not/exist.json")


# ---------- No secret leakage in logs ----------

def test_app_initialization_failure_never_logs_the_private_key(env, monkeypatch, caplog):
    """However FCM_SERVICE_ACCOUNT_JSON is broken, the private key must never end up in a log
    line. Uses a secret-shaped marker in place of a real key so the test actually proves
    something: if this string ever shows up in caplog, the logging path leaked it."""
    from app.config import get_settings

    secret_marker = "SUPER-SECRET-PRIVATE-KEY-MARKER-should-never-be-logged"
    broken_json = json.dumps({"type": "service_account", "private_key": secret_marker, "client_email": "x@y.z", "token_uri": "https://oauth2.googleapis.com/token"})
    monkeypatch.setattr(get_settings(), "fcm_service_account_json", broken_json)
    push._app.cache_clear()
    try:
        with caplog.at_level(logging.DEBUG):
            assert push._app() is None
    finally:
        push._app.cache_clear()
    assert secret_marker not in caplog.text
    assert broken_json not in caplog.text


def test_invalid_service_account_file_path_failure_never_logs_the_path_as_a_secret_surrogate(env, monkeypatch, caplog):
    """Companion to the existing test_push_handles_an_invalid_service_account_file_without_raising
    in test_api.py: also asserts on *what got logged*, not just that _app() returned None."""
    from app.config import get_settings

    monkeypatch.setattr(get_settings(), "fcm_service_account_json", "C:/definitely/does/not/exist.json")
    push._app.cache_clear()
    try:
        with caplog.at_level(logging.DEBUG):
            assert push._app() is None
    finally:
        push._app.cache_clear()
    assert "could not initialize the Firebase Admin SDK" in caplog.text

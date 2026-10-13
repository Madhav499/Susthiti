"""Per-user language preference: default, persistence, validation, and independence
across accounts (see the master prompt's "patient and doctor language must be
independent" requirement)."""

from tests.conftest import make_admin, make_doctor, register_patient

API = "/api/v1"


def test_registration_without_locale_defaults_to_english(env):
    client, _, _ = env
    headers, user = register_patient(client, email="noLocale@example.org")
    assert user["preferred_locale"] == "en"
    me = client.get(f"{API}/auth/me", headers=headers)
    assert me.json()["preferred_locale"] == "en"


def test_registration_with_locale_persists_it(env):
    client, _, _ = env
    r = client.post(f"{API}/auth/register", json={
        "full_name": "Priya Shah", "email": "priya@example.org", "password": "Password1",
        "date_of_birth": "1992-04-01", "gender": "Female", "preferred_locale": "gu",
    })
    assert r.status_code == 201, r.text
    assert r.json()["user"]["preferred_locale"] == "gu"


def test_registration_with_unsupported_locale_normalizes_to_english():
    """A presentation preference should never block account creation -- an unrecognized
    value is normalized, not rejected, unlike every other RegisterIn field."""
    from app.schemas import RegisterIn

    body = RegisterIn(full_name="Test User", email="x@example.org", password="Password1", date_of_birth="1990-01-01", gender="Male", preferred_locale="fr")
    assert body.preferred_locale == "en"


def test_user_can_change_their_own_language(env):
    client, _, _ = env
    headers, user = register_patient(client, email="lang@example.org")
    r = client.patch(f"{API}/auth/language", headers=headers, json={"locale": "hi"})
    assert r.status_code == 200, r.text
    assert r.json()["preferred_locale"] == "hi"
    # Persists across requests (and would across sessions -- it's the same DB row /auth/me reads).
    me = client.get(f"{API}/auth/me", headers=headers)
    assert me.json()["preferred_locale"] == "hi"


def test_language_update_rejects_unsupported_locale(env):
    client, _, _ = env
    headers, _ = register_patient(client, email="badlang@example.org")
    r = client.patch(f"{API}/auth/language", headers=headers, json={"locale": "fr"})
    assert r.status_code == 422


def test_language_update_requires_authentication(env):
    client, _, _ = env
    r = client.patch(f"{API}/auth/language", json={"locale": "hi"})
    assert r.status_code == 401


def test_language_preference_is_independent_per_account(env):
    """A patient choosing Gujarati must never affect their doctor's (or any other
    account's) own language, and there is no endpoint that lets one user target another's id."""
    client, _, _ = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin, email="doc.lang@example.org")
    patient_headers, _ = register_patient(client, email="pat.lang@example.org")

    client.patch(f"{API}/auth/language", headers=patient_headers, json={"locale": "gu"})
    client.patch(f"{API}/auth/language", headers=doctor_headers, json={"locale": "hi"})

    patient_me = client.get(f"{API}/auth/me", headers=patient_headers).json()
    doctor_me = client.get(f"{API}/auth/me", headers=doctor_headers).json()
    admin_me = client.get(f"{API}/auth/me", headers=admin).json()
    assert patient_me["preferred_locale"] == "gu"
    assert doctor_me["preferred_locale"] == "hi"
    assert admin_me["preferred_locale"] == "en"  # never touched, still the default


def test_doctor_created_by_admin_defaults_to_english_until_they_choose(env):
    """Doctors don't self-register (see auth.py's register() docstring); admin-created
    accounts still get a safe default rather than inheriting the admin's or anyone else's
    preference."""
    client, _, _ = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin, email="newdoc@example.org")
    r = client.get(f"{API}/auth/me", headers=doctor_headers)
    assert r.json()["preferred_locale"] == "en"

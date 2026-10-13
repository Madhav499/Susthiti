"""Viewer-specific language for AI summaries (routers/ai.py's _get_or_create /
_store_localized, services/ai/localization.py): generation always happens once in
English; a non-English viewer gets an independently cached translated row, and the
patient's language choice never affects what a doctor viewing the same report sees.
"""

import httpx

from tests.conftest import grant_access, make_admin, make_doctor, register_patient, upload

API = "/api/v1"


def _set_locale(client, headers, locale):
    r = client.patch(f"{API}/auth/language", headers=headers, json={"locale": locale})
    assert r.status_code == 200, r.text


def test_patient_and_doctor_see_the_same_report_in_their_own_language(env):
    client, _, gemini = env
    admin = make_admin(client)
    doctor_headers, _ = make_doctor(client, admin, email="doc.viewer@example.org")
    patient_headers, patient = register_patient(client, email="pat.viewer@example.org")
    grant_access(client, doctor_headers, patient_headers, patient)
    pid = patient["patient_id"]
    report = upload(client, patient_headers, pid).json()

    _set_locale(client, patient_headers, "gu")

    gemini.queue_json({"summary": "Your HbA1c is 7.1%, which is above the normal range."})
    gemini.queue_json({"summary": "તમારું HbA1c 7.1% છે, જે સામાન્ય શ્રેણી કરતા વધારે છે."})
    patient_view = client.post(f"{API}/reports/{report['id']}/summary", headers=patient_headers)
    assert patient_view.status_code == 201, patient_view.text
    assert patient_view.json()["summary"]["locale"] == "gu"
    assert patient_view.json()["summary"]["content"]["summary"] == "તમારું HbA1c 7.1% છે, જે સામાન્ય શ્રેણી કરતા વધારે છે."
    assert len(gemini.requests) == 2  # one English generation, one translation

    # The doctor (still English) reads the SAME report: the already-generated English
    # canonical is reused directly -- no new AI call, and never the patient's Gujarati text.
    doctor_view = client.post(f"{API}/reports/{report['id']}/summary", headers=doctor_headers)
    assert doctor_view.status_code == 200, doctor_view.text
    assert doctor_view.json()["created"] is False
    assert doctor_view.json()["summary"]["locale"] == "en"
    assert doctor_view.json()["summary"]["content"]["summary"] == "Your HbA1c is 7.1%, which is above the normal range."
    assert len(gemini.requests) == 2  # still just the two calls from the patient's request

    # Clinical fact (the number) is identical in both languages.
    assert "7.1" in patient_view.json()["summary"]["content"]["summary"]
    assert "7.1" in doctor_view.json()["summary"]["content"]["summary"]


def test_translation_that_drops_a_number_falls_back_to_english_for_that_field(env):
    client, _, gemini = env
    headers, patient = register_patient(client, email="numeric@example.org")
    report = upload(client, headers, patient["patient_id"]).json()
    _set_locale(client, headers, "hi")

    gemini.queue_json({"summary": "Your blood sugar is 140 mg/dL, slightly above target."})
    # Simulates a bad translation that lost the number -- must never be shown as-is.
    gemini.queue_json({"summary": "आपकी ब्लड शुगर सामान्य से थोड़ी ज़्यादा है।"})
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201, r.text
    body = r.json()["summary"]
    assert body["translation_fallback"] is True
    assert body["content"]["summary"] == "Your blood sugar is 140 mg/dL, slightly above target."


def test_ai_failure_during_translation_falls_back_to_english_content(env):
    client, _, gemini = env
    headers, patient = register_patient(client, email="fallback@example.org")
    report = upload(client, headers, patient["patient_id"]).json()
    _set_locale(client, headers, "hi")

    gemini.queue_json({"summary": "Your cholesterol is within the normal range."})
    gemini.queue_raw(httpx.Response(400))  # non-retryable: the translation call fails outright
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201, r.text
    body = r.json()["summary"]
    assert body["translation_fallback"] is True
    assert body["content"]["summary"] == "Your cholesterol is within the normal range."
    assert body["locale"] == "hi"  # the row is still the viewer's locale; only the text fell back


def test_relevant_values_are_never_altered_by_translation(env):
    """Lab values, units and reference ranges must reach the viewer byte-identical to the
    English generation, regardless of what the translation call returns for them."""
    client, _, gemini = env
    headers, patient = register_patient(client, email="values@example.org")
    report = upload(client, headers, patient["patient_id"]).json()
    _set_locale(client, headers, "hi")

    gemini.queue_json({
        "summary": "Your HbA1c is slightly high.",
        "relevant_values": [{"name": "HbA1c", "value": "7.1", "unit": "%", "reference_range": "4.0-5.6"}],
    })
    # Even if the model also returns (mistranslated/garbled) relevant_values, they must be ignored.
    gemini.queue_json({
        "summary": "आपका HbA1c थोड़ा ज़्यादा है।",
        "relevant_values": [{"name": "HbA1c badly translated", "value": "9.9", "unit": "mg", "reference_range": "wrong"}],
    })
    r = client.post(f"{API}/reports/{report['id']}/summary", headers=headers)
    assert r.status_code == 201, r.text
    values = r.json()["summary"]["content"]["relevant_values"]
    assert values == [{"name": "HbA1c", "value": "7.1", "unit": "%", "reference_range": "4.0-5.6", "note": None}]

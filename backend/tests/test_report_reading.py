"""Reports with several types, and diabetes values read automatically from report files."""

import io
from datetime import date, timedelta

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

from app.config import get_settings
from app.services.health_data.report_extraction import parse_values
from tests.conftest import register_patient

API = "/api/v1"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64  # a photo of a report (no text to read)


def lab_pdf(lines: list[str]) -> bytes:
    buf = io.BytesIO()
    c = canvas.Canvas(buf, pagesize=A4)
    y = 800
    for line in lines:
        c.drawString(40, y, line)
        y -= 18
    c.save()
    return buf.getvalue()


FULL_BODY = [
    "SUSTHITI TEST LABORATORY - FULL BODY CHECKUP",
    "Test Name                           Result   Unit     Biological Reference Interval",
    "HbA1c (Glycated Haemoglobin)        6.1      %        4.0 - 5.6",
    "Estimated Average Glucose (eAG)     128      mg/dL",
    "Glucose, Fasting (FBS)              104      mg/dL    70 - 100",
    "Post Prandial Blood Sugar (PPBS)    160      mg/dL    < 140",
    "Interpretation (HbA1c %): < 5.7 Normal; 5.7 - 6.4 Prediabetes; >= 6.5 Diabetes",
    "Haemoglobin                         13.8     g/dL     12.0 - 15.0",
]


def upload(client, headers, pid, data, filename="report.pdf", category="full_body", mime="application/pdf"):
    r = client.post(f"{API}/patients/{pid}/reports", headers=headers,
                    data={"category": category, "report_date": (date.today() - timedelta(days=3)).isoformat()},
                    files={"file": (filename, data, mime)})
    assert r.status_code == 201, r.text
    return r.json()


def test_parser_takes_results_not_ranges_cutoffs_or_other_glucose():
    values = parse_values("\n".join(FULL_BODY))
    assert {k: v["value"] for k, v in values.items()} == {"hba1c": 6.1, "fasting_glucose": 104.0}
    other = parse_values("Random Blood Sugar (RBS)  8.2 mmol/L\nOGTT 2 hr (75 g)  182 mg/dL\nGlucose Fasting 5.6\nHbA1c (IFCC) 43 mmol/mol")
    assert {k: v["value"] for k, v in other.items()} == {"random_glucose": 147.7, "ogtt_2h": 182.0}  # unit-less 5.6 and mmol/mol skipped
    conflicting = parse_values("Fasting Blood Sugar 98 mg/dL\nFasting Blood Sugar 132 mg/dL")
    assert "fasting_glucose" not in conflicting


def test_values_are_read_on_upload_and_used_straight_away(env):
    client, ml, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, headers, pid, lab_pdf(FULL_BODY))
    values = client.get(f"{API}/reports/{report['id']}/values", headers=headers).json()
    assert {(v["analyte"], v["value"], v["needs_check"]) for v in values["values"]} == {("hba1c", 6.1, True), ("fasting_glucose", 104.0, True)}
    assert values["extraction"]["note"] == "Read automatically from the report's text."
    a = client.post(f"{API}/patients/{pid}/diabetes-risk", headers=headers).json()["assessment"]
    assert (ml.calls[0]["hba1c"], ml.calls[0]["fasting_glucose"]) == (6.1, 104.0)
    assert "previous_health_report_status" not in ml.calls[0]  # the conclusion is never read automatically
    item = next(g for g in a["data_used"]["groups"] if g["key"] == "report")["items"][0]
    assert "read automatically from the report, not yet checked" in item["detail"]

    # "Looks right": now checked by the patient; the value itself is unchanged.
    confirmed = client.put(f"{API}/reports/{report['id']}/values", headers=headers, json={"values": {"hba1c": {"origin": "confirm"}}}).json()
    hba1c = next(v for v in confirmed["values"] if v["analyte"] == "hba1c")
    assert (hba1c["value"], hba1c["needs_check"], hba1c["confirmed_by_role"]) == (6.1, False, "patient")
    # A correction replaces the automatic value; it is never overwritten by a later automatic read.
    client.put(f"{API}/reports/{report['id']}/values", headers=headers, json={"values": {"fasting_glucose": {"value": 101, "unit": "mg/dL"}}})
    client.post(f"{API}/reports/{report['id']}/values/read", headers=headers)
    fasting = next(v for v in client.get(f"{API}/reports/{report['id']}/values", headers=headers).json()["values"] if v["analyte"] == "fasting_glucose")
    assert (fasting["value"], fasting["needs_check"]) == (101.0, False)


def test_photos_are_read_by_the_ai_reader_with_the_same_checks(env, monkeypatch):
    client, _, gemini = env
    monkeypatch.setattr(get_settings(), "ai_read_report_values", True)
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    gemini.queue_json({"values": [
        {"test": "hba1c", "value": "6.4", "unit": "%", "printed_name": "HbA1c"},
        {"test": "fasting_glucose", "value": "<100", "unit": "mg/dL"},  # not a result
        {"test": "ldl", "value": "130", "unit": "mg/dL"},  # not a diabetes measure
    ]})
    report = upload(client, headers, pid, PNG, "report.png", "hba1c", "image/png")
    values = client.get(f"{API}/reports/{report['id']}/values", headers=headers).json()
    assert [(v["analyte"], v["value"], v["origin"]) for v in values["values"]] == [("hba1c", 6.4, "ai_extracted")]
    assert gemini.requests[0]["messages"][1]["content"][0]["image_url"]["url"].startswith("data:image/png")


def test_photos_without_the_ai_reader_say_so(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    report = upload(client, headers, patient["patient_id"], PNG, "scan.png", "blood_report", "image/png")
    values = client.get(f"{API}/reports/{report['id']}/values", headers=headers).json()
    assert values["values"] == [] and "scan or photo" in values["extraction"]["note"]


def test_a_report_can_have_several_types(env):
    client, _, _ = env
    headers, patient = register_patient(client)
    pid = patient["patient_id"]
    report = upload(client, headers, pid, lab_pdf(["Lipid profile"]), category="full_body,hba1c,lipid_profile")
    assert report["categories"] == ["full_body", "hba1c", "lipid_profile"] and report["category"] == "full_body"
    for group in ("hba1c", "blood", "lipid_profile"):
        assert client.get(f"{API}/patients/{pid}/reports", headers=headers, params={"category": group}).json()["total"] == 1, group
    assert client.get(f"{API}/patients/{pid}/reports", headers=headers, params={"category": "imaging"}).json()["total"] == 0
    event = client.get(f"{API}/patients/{pid}/timeline", headers=headers, params={"type": "reports"}).json()["items"][0]
    assert event["title"] == "Full Body Checkup, HbA1c, Lipid Profile report"
    bad = client.post(f"{API}/patients/{pid}/reports", headers=headers, data={"category": "full_body,nonsense", "report_date": "2026-01-01"},
                      files={"file": ("r.pdf", lab_pdf(["x"]), "application/pdf")})
    assert bad.status_code == 422

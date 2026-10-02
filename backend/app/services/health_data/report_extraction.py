"""Reads diabetes-related values (HbA1c, fasting / random glucose, 2-hour OGTT) from an uploaded
report automatically, so the patient doesn't type them.

1. Text PDFs (most lab reports): the report's own text is parsed with strict rules below.
2. Scanned PDFs and photos: when the AI service is configured, it is asked to copy these four
   results exactly as printed; the answer goes through the same checks.

Values read automatically are used straight away and shown as "read automatically, please check";
the patient or a doctor can confirm or correct them on the report. Nothing is inferred: a value is
taken only when its test name is unambiguous, the number is the patient's result (not a reference
range or cut-off), the unit is known, and the report shows one value for that test. The report's
conclusion (Normal / Prediabetes / Diabetes) is never read automatically: HbA1c reports print an
interpretation table with all three words, so text alone can't tell which applies.
"""

import io
import logging
import re
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from ...models import Report, ReportValue
from . import report_values as rv

log = logging.getLogger("susthiti.report_extraction")

AUTOMATIC = "automatic"  # confirmed_by_role of a value no person has checked yet
TEXT, AI = "auto_extracted", "ai_extracted"  # ReportValue.origin

_NAMES = {
    "hba1c": re.compile(r"\b(?:hb\s*a1c|hba1c|glyc(?:at|osyl)ated\s+ha?emoglobin|glycohemoglobin)\b", re.I),
    "fasting_glucose": re.compile(
        r"\b(?:fasting\s+(?:blood\s+|plasma\s+|serum\s+)?(?:glucose|sugar)"
        r"|(?:blood\s+|plasma\s+|serum\s+)?(?:glucose|sugar)\s*[-,:(]*\s*\(?\s*fasting"
        r"|f\.?b\.?s|f\.?b\.?g|f\.?p\.?g)\b", re.I),
    "random_glucose": re.compile(
        r"\b(?:random\s+(?:blood\s+|plasma\s+|serum\s+)?(?:glucose|sugar)"
        r"|(?:blood\s+|plasma\s+|serum\s+)?(?:glucose|sugar)\s*[-,:(]*\s*\(?\s*random"
        r"|r\.?b\.?s|r\.?b\.?g)\b", re.I),
    "ogtt_2h": re.compile(
        r"(?:\b(?:2|two)\s*-?\s*(?:hours?|hrs?|h)\b[^\n]{0,30}?(?:ogtt|glucose\s+tolerance|post\s*-?\s*glucose|75\s*g)"
        r"|\bogtt\b[^\n]{0,25}?\b(?:2|two)\s*-?\s*(?:hours?|hrs?|h)\b)", re.I),
}
# Lines about other measurements that share words with the ones above.
_EXCLUDE = re.compile(
    r"estimated\s+average|\beag\b|mean\s+(?:blood\s+|plasma\s+)?glucose|prandial|\bppbs\b|\bp\.?p\.?\b|after\s+(?:a\s+)?meal|urine"
    # Interpretation tables and reference ranges ("< 5.7 Normal; 5.7 - 6.4 Prediabetes; >= 6.5 Diabetes").
    r"|interpretation|reference\s+(?:range|interval|value)|pre-?\s*diabet|non-?\s*diabetic", re.I)
# Words or signs that make the following number a limit, not the patient's result.
_LIMIT_BEFORE = re.compile(r"(?:[<>≤≥=]|less\s+than|more\s+than|up\s*to|upto|above|below|over|under)\s*$", re.I)
# A number that is the result: not part of a reference range or a cut-off.
_NUMBER = re.compile(r"(?<![\d.<>≤≥=])(\d{1,3}(?:\.\d{1,2})?)(?![\d.])(?!\s*[-–—]\s*\d)")
_UNIT = re.compile(r"^\s*(%|mg\s*/\s*dl|mmol\s*/\s*mol|mmol\s*/\s*l)\b|^\s*%", re.I)


def pdf_text(data: bytes) -> str | None:
    try:
        from pypdf import PdfReader

        reader = PdfReader(io.BytesIO(data))
        text = "\n".join((page.extract_text() or "") for page in reader.pages[:20])
        return text if text.strip() else None
    except Exception as exc:  # malformed or encrypted PDF: just no text
        log.info("pdf text extraction failed type=%s", type(exc).__name__)
        return None


def parse_values(text: str) -> dict[str, dict]:
    """analyte -> {value (canonical), unit, entered_value, entered_unit, line}. Only unambiguous ones."""
    found: dict[str, dict | None] = {}
    for raw in text.splitlines():
        line = " ".join(raw.split())
        if not line or _EXCLUDE.search(line):
            continue
        for key, pattern in _NAMES.items():
            match = pattern.search(line)
            if not match:
                continue
            tail = line[match.end():]
            if key == "ogtt_2h":
                tail = re.sub(r"^[^\d]*?\b(?:2|two)\s*-?\s*(?:hours?|hrs?|h)\b", "", tail, count=1, flags=re.I)
            value = _result(rv.ANALYTES[key], tail)
            if value is None:
                continue
            previous = found.get(key, "unset")
            if previous == "unset":
                found[key] = {**value, "line": line[:200]}
            elif previous is not None and previous["value"] != value["value"]:
                found[key] = None  # two different results for one test: ambiguous
    return {k: v for k, v in found.items() if v}


def _result(analyte: rv.Analyte, tail: str) -> dict | None:
    for number in _NUMBER.finditer(tail):
        if _LIMIT_BEFORE.search(tail[:number.start()]):
            continue  # "< 5.7", "less than 100": a limit, not the patient's result
        after = tail[number.end():number.end() + 14]
        if re.match(r"\s*(?:g|gm|gms|grams?)\b", after, re.I):
            continue  # "75 g": the OGTT glucose dose, not a result
        unit_match = _UNIT.match(after)
        unit = unit_match.group(0).strip().lower().replace(" ", "") if unit_match else None
        raw = float(number.group(1))
        if unit == "mmol/mol":
            return None  # IFCC HbA1c: not converted
        if analyte.key == "hba1c":
            entered_unit = "%"
            if unit not in (None, "%"):
                return None
        else:
            if unit == "%":
                continue  # a percentage next to a glucose name is something else
            if unit is None:
                if raw < 40:
                    return None  # could be mmol/L: ambiguous without a unit
                entered_unit = "mg/dL"
            else:
                entered_unit = "mg/dL" if unit == "mg/dl" else "mmol/L"
        try:
            canonical = rv.to_canonical(analyte, raw, entered_unit)
        except ValueError:
            return None
        return {"value": canonical, "unit": analyte.unit, "entered_value": raw, "entered_unit": entered_unit}
    return None


def store_values(db: Session, report: Report, values: dict[str, dict], origin: str) -> list[str]:
    """Adds automatically read values, never replacing one a person entered or confirmed."""
    active = {v.analyte: v for v in rv.active_values(db, report_id=report.id)}
    now = datetime.now(timezone.utc)
    stored = []
    for key, v in values.items():
        existing = active.get(key)
        if existing is not None and existing.confirmed_by_role != AUTOMATIC:
            continue
        if existing is not None:
            if existing.value == v["value"]:
                continue
            existing.superseded_at = now
        db.add(ReportValue(
            report_id=report.id, patient_id=report.patient_id, analyte=key, value=v["value"], unit=v["unit"],
            entered_value=v["entered_value"], entered_unit=v["entered_unit"], measured_on=report.report_date,
            origin=origin, confirmed_by_user_id=report.uploader_user_id, confirmed_by_role=AUTOMATIC, confirmed_at=now,
            previous_id=existing.id if existing else None,
        ))
        stored.append(key)
    return stored


def extract_from_text(db: Session, report: Report, data: bytes) -> list[str]:
    """Runs on upload. Returns the measures stored; records what happened on the report."""
    report.values_extracted_at = datetime.now(timezone.utc)
    text = pdf_text(data) if report.file_type == "application/pdf" else None
    if text is None:
        report.values_extraction_note = "This report is a scan or photo, so its text can't be read directly."
        return []
    stored = store_values(db, report, parse_values(text), TEXT)
    found = rv.active_values(db, report_id=report.id)
    report.values_extraction_note = (
        "Read automatically from the report's text." if stored or found
        else "No HbA1c or glucose results were found in this report's text."
    )
    return stored


def needs_ai(report: Report) -> bool:
    """Nothing found in the text (or no text at all): the AI reader may still find values."""
    from ...config import get_settings

    settings = get_settings()
    return (settings.ai_configured and settings.ai_read_report_values and report.values_extraction_note is not None
            and "Read automatically" not in report.values_extraction_note)


def extract_with_ai(db: Session, report: Report, data: bytes) -> list[str]:
    from ..ai.services import LabValuesExtractionService, get_ai_client

    result = LabValuesExtractionService(get_ai_client()).extract(data, report.file_type)
    values: dict[str, dict | None] = {}
    for item in result.content.get("values") or []:
        key = str(item.get("test") or "").strip().lower()
        if key not in rv.SUGGESTIBLE:
            continue
        raw = str(item.get("value") or "").strip()
        if not re.fullmatch(r"\d{1,3}(\.\d{1,2})?", raw):
            continue
        parsed = _result(rv.ANALYTES[key], f" {raw} {item.get('unit') or ''}")
        if parsed is None:
            continue
        if key in values and (values[key] is None or values[key]["value"] != parsed["value"]):
            values[key] = None
            continue
        values[key] = parsed
    stored = store_values(db, report, {k: v for k, v in values.items() if v}, AI)
    report.values_extracted_at = datetime.now(timezone.utc)
    report.values_extraction_note = (
        "Read automatically from the report by the AI reader." if stored or rv.active_values(db, report_id=report.id)
        else "No HbA1c or glucose results could be read from this report."
    )
    return stored


def extract_in_background(report_id: str) -> None:
    """After an upload: the AI reader runs without keeping the patient waiting."""
    from ...db import SessionLocal
    from ..storage import get_storage

    with SessionLocal() as db:
        report = db.get(Report, report_id)
        if report is None or not needs_ai(report):
            return
        try:
            extract_with_ai(db, report, get_storage().read(report.storage_ref))
            db.commit()
        except Exception as exc:  # the report itself is safe; values can still be added by hand
            log.warning("AI value extraction failed report=%s type=%s", report.report_code, type(exc).__name__)
            db.rollback()

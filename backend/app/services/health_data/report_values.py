"""Structured values from uploaded reports.

A report is stored as a file; its values become usable health data only once a person (the
patient or a doctor) confirms them on that report. The AI report summary, when one exists, only
*suggests* values, and only when its value name matches a known name exactly and the unit is one
we can convert: no fuzzy matching, and anything ambiguous is not suggested.

Selection policy for "the current value" of each measure: the newest report date wins (then the
most recent confirmation); values from reports older than MAX_AGE_DAYS are kept in history but
not used as current health data. Older values stay available as history, never overwritten.
"""

import re
from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import AISummary, Report, ReportValue

MAX_AGE_DAYS = 730  # 2 years
MG_DL_PER_MMOL_L = 18.0182  # glucose


@dataclass(frozen=True)
class Analyte:
    key: str
    label: str
    kind: str  # number | classification
    unit: str | None = None
    units: dict | None = None  # accepted unit (normalised) -> factor to the canonical unit
    min: float | None = None
    max: float | None = None
    names: frozenset[str] = frozenset()  # exact normalised names accepted from AI summaries
    options: tuple[tuple[str, str], ...] = ()
    precision: int = 1  # decimal places kept in the canonical value (troponin needs more than 1)


def _names(*names: str) -> frozenset[str]:
    return frozenset(normalise_name(n) for n in names)


def normalise_name(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


_GLUCOSE_UNITS = {"mgdl": 1.0, "mmoll": MG_DL_PER_MMOL_L}
# Cholesterol-family and triglycerides have different mg/dL-per-mmol/L factors (different
# molecular weights); creatinine and hemoglobin use their own standard SI conversions.
MG_DL_PER_MMOL_L_CHOLESTEROL = 38.67
MG_DL_PER_MMOL_L_TRIGLYCERIDES = 88.57
MG_DL_PER_UMOL_L_CREATININE = 1 / 88.4
_CHOLESTEROL_UNITS = {"mgdl": 1.0, "mmoll": MG_DL_PER_MMOL_L_CHOLESTEROL}
_TRIGLYCERIDE_UNITS = {"mgdl": 1.0, "mmoll": MG_DL_PER_MMOL_L_TRIGLYCERIDES}
_CREATININE_UNITS = {"mgdl": 1.0, "umoll": MG_DL_PER_UMOL_L_CREATININE}
_HEMOGLOBIN_UNITS = {"gdl": 1.0, "gl": 0.1}

ANALYTES: dict[str, Analyte] = {a.key: a for a in (
    Analyte("hba1c", "HbA1c", "number", unit="%", units={"": 1.0, "%": 1.0}, min=3, max=20,
            names=_names("HbA1c", "Hb A1c", "HbA1C (Glycated Haemoglobin)", "Glycated haemoglobin", "Glycated hemoglobin",
                         "Glycosylated haemoglobin", "Glycosylated hemoglobin", "A1c", "Haemoglobin A1c", "Hemoglobin A1c")),
    Analyte("fasting_glucose", "Fasting glucose", "number", unit="mg/dL", units=_GLUCOSE_UNITS, min=20, max=700,
            names=_names("Fasting blood glucose", "Fasting blood sugar", "Fasting plasma glucose", "FBS", "FBG", "FPG",
                         "Glucose fasting", "Glucose (fasting)", "Blood sugar fasting", "Blood glucose fasting")),
    Analyte("random_glucose", "Random glucose", "number", unit="mg/dL", units=_GLUCOSE_UNITS, min=20, max=900,
            names=_names("Random blood glucose", "Random blood sugar", "Random plasma glucose", "RBS", "RBG",
                         "Glucose random", "Glucose (random)", "Blood sugar random")),
    Analyte("ogtt_2h", "2-hour OGTT glucose", "number", unit="mg/dL", units=_GLUCOSE_UNITS, min=20, max=900,
            names=_names("2 hour OGTT", "2-hour OGTT", "OGTT 2 hour", "OGTT 2 hr", "OGTT 2h", "2 hr plasma glucose OGTT",
                         "Glucose tolerance test 2 hour", "2 hour glucose (75 g OGTT)")),
    Analyte("diabetes_classification", "Report conclusion (diabetes)", "classification",
            options=(("normal", "Normal"), ("prediabetes", "Prediabetes"), ("diabetes", "Diabetes"))),
    # Heart-disease screening lab values (reused by the heart risk assessment; see
    # services/heart_risk/features.py). Ranges mirror the heart model API's own accepted ranges
    # so a confirmed value is never rejected here only to be unusable there.
    Analyte("total_cholesterol", "Total cholesterol", "number", unit="mg/dL", units=_CHOLESTEROL_UNITS, min=50, max=1000,
            names=_names("Total Cholesterol", "Cholesterol Total", "Cholesterol, Total", "Serum Cholesterol", "Total Chol", "Cholesterol")),
    Analyte("ldl", "LDL cholesterol", "number", unit="mg/dL", units=_CHOLESTEROL_UNITS, min=10, max=600,
            names=_names("LDL", "LDL Cholesterol", "LDL-C", "Low Density Lipoprotein", "LDL Cholesterol (Calculated)", "LDL Chol")),
    Analyte("hdl", "HDL cholesterol", "number", unit="mg/dL", units=_CHOLESTEROL_UNITS, min=5, max=250,
            names=_names("HDL", "HDL Cholesterol", "HDL-C", "High Density Lipoprotein", "HDL Chol")),
    Analyte("triglycerides", "Triglycerides", "number", unit="mg/dL", units=_TRIGLYCERIDE_UNITS, min=20, max=2000,
            names=_names("Triglycerides", "TG", "Serum Triglycerides", "Trig")),
    Analyte("troponin", "Troponin", "number", unit="ng/mL", units={"ngml": 1.0}, min=0, max=100, precision=2,
            names=_names("Troponin", "Troponin I", "Troponin T", "Cardiac Troponin", "Trop I", "Trop T", "cTnI", "cTnT", "hs-Troponin")),
    Analyte("hemoglobin", "Hemoglobin", "number", unit="g/dL", units=_HEMOGLOBIN_UNITS, min=3, max=25,
            names=_names("Hemoglobin", "Haemoglobin", "Hb", "Hgb")),
    Analyte("creatinine", "Creatinine", "number", unit="mg/dL", units=_CREATININE_UNITS, min=0.1, max=20, precision=2,
            names=_names("Creatinine", "Serum Creatinine", "Creat")),
)}

# Only values of these measures are suggested from AI summaries, and auto-extracted (then
# flagged "please check") straight from an uploaded report's text/photo on upload (see
# report_extraction.py). Deliberately NOT extended to the new heart-screening lab values below:
# unlike the diabetes measures, those have no prior auto-extraction track record in this app,
# so -- more conservatively -- they can only enter SUSTHITI through an explicit human
# confirmation on the report (the generic "Add or correct values" form, which lists every
# ANALYTES entry regardless of SUGGESTIBLE). The classification is never inferred either way:
# it has to be read off the report by a person.
SUGGESTIBLE = ("hba1c", "fasting_glucose", "random_glucose", "ogtt_2h")


def _unit_key(unit: str | None) -> str:
    return (unit or "").strip().lower().replace(" ", "").replace("/", "")


def to_canonical(analyte: Analyte, value: float, unit: str | None) -> float:
    """Converts an entered value to the analyte's canonical unit, or raises ValueError."""
    factor = (analyte.units or {}).get(_unit_key(unit))
    if factor is None:
        raise ValueError(f"{analyte.label}: unit must be {' or '.join(u for u in _display_units(analyte))}.")
    canonical = round(float(value) * factor, analyte.precision)
    if (analyte.min is not None and canonical < analyte.min) or (analyte.max is not None and canonical > analyte.max):
        raise ValueError(f"{analyte.label} of {value:g} {unit or analyte.unit} is outside the possible range. Please check the report.")
    return canonical


_UNIT_DISPLAY = {"": "%", "%": "%", "mgdl": "mg/dL", "mmoll": "mmol/L", "gdl": "g/dL", "gl": "g/L", "umoll": "µmol/L", "ngml": "ng/mL"}


def _display_units(analyte: Analyte) -> list[str]:
    """De-duplicated (hba1c's units dict maps both "" and "%" to the same canonical unit)."""
    out: list[str] = []
    for k in (analyte.units or {}):
        label = _UNIT_DISPLAY[k]
        if label not in out:
            out.append(label)
    return out


def unit_options(analyte: Analyte) -> list[str]:
    return _display_units(analyte) if analyte.kind == "number" else []


def suggestions_from_summary(content: dict) -> list[dict]:
    """Values an AI report summary lists that map unambiguously to a known measure."""
    found: dict[str, dict] = {}
    for item in content.get("relevant_values") or []:
        if not isinstance(item, dict):
            continue
        name = normalise_name(str(item.get("name") or ""))
        matches = [a for a in (ANALYTES[k] for k in SUGGESTIBLE) if name in a.names]
        if len(matches) != 1:
            continue
        analyte = matches[0]
        raw = str(item.get("value") or "").strip()
        if not re.fullmatch(r"\d+(\.\d+)?", raw):  # one plain number only (no ranges, no "<", no text)
            continue
        unit = item.get("unit")
        try:
            canonical = to_canonical(analyte, float(raw), unit if unit is not None else ("%" if analyte.unit == "%" else None))
        except ValueError:
            continue
        if analyte.key in found:
            previous = found[analyte.key]
            if previous is not None and previous["value"] == canonical:
                continue  # the same value listed twice
            found[analyte.key] = None  # two different values for one measure: ambiguous, suggest neither
            continue
        found[analyte.key] = {"analyte": analyte.key, "value": canonical, "unit": analyte.unit, "entered_value": float(raw),
                              "entered_unit": unit or analyte.unit, "source_name": item.get("name")}
    return [s for s in found.values() if s is not None]


# The 4 diabetes-control analytes where "lower is better" is unambiguous in this app's domain.
# Every other parameter the AI cites (e.g. a lipid value) has no known clinical polarity here,
# so its direction is reported neutrally ("recent_change") rather than guessed as good or bad.
_LOWER_IS_BETTER = {"hba1c", "fasting_glucose", "random_glucose", "ogtt_2h"}

_LEADING_NUMBER = re.compile(r"[-+]?\d+(?:\.\d+)?")


def _match_known_analyte(parameter_name: str) -> str | None:
    name = normalise_name(parameter_name)
    for analyte in ANALYTES.values():
        if name in analyte.names:
            return analyte.key
    return None


def classify_trend(parameter_name: str, earlier_value: str | None, latest_value: str | None) -> dict:
    """Deterministically classifies a trend's direction from two cited values -- never from
    the AI's wording. `direction` is purely numeric; `category` additionally applies known
    clinical polarity (see _LOWER_IS_BETTER) where it is safe to do so."""
    earlier_match = _LEADING_NUMBER.search(earlier_value or "")
    latest_match = _LEADING_NUMBER.search(latest_value or "")
    if not earlier_match or not latest_match:
        return {"direction": "unknown", "category": "unknown"}
    earlier = float(earlier_match.group())
    latest = float(latest_match.group())
    denominator = abs(earlier) if earlier else 1.0
    relative_change = (latest - earlier) / denominator
    if abs(relative_change) < 0.03:
        direction = "unchanged"
    else:
        direction = "increased" if latest > earlier else "decreased"

    analyte_key = _match_known_analyte(parameter_name)
    if analyte_key not in _LOWER_IS_BETTER:
        category = "stable" if direction == "unchanged" else "recent_change"
    else:
        category = {"unchanged": "stable", "increased": "worsening", "decreased": "improving"}[direction]
    return {"direction": direction, "category": category}


def latest_report_summary(db: Session, report_id: str) -> AISummary | None:
    return db.scalar(
        select(AISummary).where(AISummary.kind == "individual_report", AISummary.subject_id == report_id)
        .order_by(AISummary.generated_at.desc()).limit(1)
    )


def active_values(db: Session, *, report_id: str | None = None, patient_id: str | None = None) -> list[ReportValue]:
    query = select(ReportValue).where(ReportValue.superseded_at.is_(None), ReportValue.removed.is_(False))
    if report_id:
        query = query.where(ReportValue.report_id == report_id)
    if patient_id:
        query = query.where(ReportValue.patient_id == patient_id)
    return list(db.scalars(query))


@dataclass
class CurrentValue:
    analyte: str
    current: ReportValue
    report: Report
    previous: ReportValue | None
    previous_report: Report | None
    too_old: bool


def current_values(db: Session, patient_id: str, today: date) -> dict[str, CurrentValue]:
    """Per measure: the value from the newest report, and the one before it (history)."""
    rows = active_values(db, patient_id=patient_id)
    reports = {r.id: r for r in db.scalars(select(Report).where(Report.id.in_({v.report_id for v in rows})))} if rows else {}
    by_analyte: dict[str, list[ReportValue]] = {}
    for row in rows:
        by_analyte.setdefault(row.analyte, []).append(row)
    out: dict[str, CurrentValue] = {}
    for analyte, values in by_analyte.items():
        values.sort(key=lambda v: (v.measured_on, _aware_ts(v.confirmed_at)), reverse=True)
        current = values[0]
        previous = next((v for v in values[1:] if v.report_id != current.report_id), None)
        out[analyte] = CurrentValue(
            analyte=analyte, current=current, report=reports[current.report_id], previous=previous,
            previous_report=reports.get(previous.report_id) if previous else None,
            too_old=(today - current.measured_on).days > MAX_AGE_DAYS,
        )
    return out


def _aware_ts(dt):
    return dt.timestamp() if dt else 0

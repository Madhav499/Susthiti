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


def _names(*names: str) -> frozenset[str]:
    return frozenset(normalise_name(n) for n in names)


def normalise_name(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


_GLUCOSE_UNITS = {"mgdl": 1.0, "mmoll": MG_DL_PER_MMOL_L}

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
)}

# Only values of these measures are suggested from AI summaries (the classification is never
# inferred: it has to be read off the report by a person).
SUGGESTIBLE = ("hba1c", "fasting_glucose", "random_glucose", "ogtt_2h")


def _unit_key(unit: str | None) -> str:
    return (unit or "").strip().lower().replace(" ", "").replace("/", "")


def to_canonical(analyte: Analyte, value: float, unit: str | None) -> float:
    """Converts an entered value to the analyte's canonical unit, or raises ValueError."""
    factor = (analyte.units or {}).get(_unit_key(unit))
    if factor is None:
        raise ValueError(f"{analyte.label}: unit must be {' or '.join(u for u in _display_units(analyte))}.")
    canonical = round(float(value) * factor, 1)
    if (analyte.min is not None and canonical < analyte.min) or (analyte.max is not None and canonical > analyte.max):
        raise ValueError(f"{analyte.label} of {value:g} {unit or analyte.unit} is outside the possible range. Please check the report.")
    return canonical


def _display_units(analyte: Analyte) -> list[str]:
    return ["%"] if analyte.unit == "%" else ["mg/dL", "mmol/L"]


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

"""The patient's health profile and the structured values confirmed from their reports.

Patients edit their own; a doctor with approved access can also record them (their role is
kept with every value). Admins can read, never write. Every change is appended, never edited.
"""

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, require_clinical, require_record_reader
from ..models import HealthFact, Report, ReportValue
from ..schemas import iso
from ..services.health_data import latest_facts, profile_fields as pf
from ..services.health_data.body import body_measurements
from ..services.health_data import report_values as rv
from ..services.health_data.report_extraction import AUTOMATIC, extract_from_text, extract_with_ai, needs_ai
from ..services.storage import get_storage
from ..services.records import audit

router = APIRouter(tags=["health data"])


class HealthProfileIn(BaseModel):
    # field -> value; null records "not sure". Fields left out are unchanged.
    values: dict[str, Any] = Field(default_factory=dict)


class ReportValueIn(BaseModel):
    value: float | None = None
    unit: str | None = None
    text_value: str | None = None
    origin: str = "manual"  # manual | ai_suggestion


class ReportValuesIn(BaseModel):
    # analyte -> new value, or null to record that this report does not contain it.
    values: dict[str, ReportValueIn | None] = Field(default_factory=dict)


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _profile_out(db: Session, patient) -> dict:
    latest = latest_facts(db, patient.id)
    now = datetime.now(timezone.utc)
    fields = []
    for spec in pf.FIELDS:
        fact = latest.get(spec.key)
        expired = bool(fact and spec.fresh_days is not None and (now - _aware(fact.recorded_at)).days > spec.fresh_days)
        fields.append({
            "key": spec.key, "group": spec.group, "label": spec.label, "kind": spec.kind,
            "options": [{"value": v, "label": label} for v, label in spec.options], "unit": spec.unit, "min": spec.min, "max": spec.max,
            "applies_to": spec.applies_to, "help": spec.help, "fresh_days": spec.fresh_days,
            "answered": fact is not None, "value": None if fact is None else fact.value,
            "recorded_at": None if fact is None else iso(fact.recorded_at), "recorded_by_role": None if fact is None else fact.recorded_by_role,
            "needs_update": expired, "doctor_only": spec.key in pf.DOCTOR_ONLY,
        })
    return {
        "patient_id": patient.id, "sex": patient.gender, "body": body_measurements(db, patient.id),
        "groups": [{"key": key, "label": label} for key, label in pf.GROUP_LABELS.items()],
        "fields": fields,
    }


@router.get("/patients/{patient_id}/health-profile")
def get_health_profile(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    return _profile_out(db, authorize_patient(db, current, patient_id))


@router.put("/patients/{patient_id}/health-profile")
def update_health_profile(patient_id: str, body: HealthProfileIn, current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    unknown = sorted(set(body.values) - set(pf.BY_KEY))
    if unknown:
        raise errors.unprocessable("Unknown health profile field.", {"fields": unknown})
    if current.role == "patient":
        restricted = sorted(set(body.values) & pf.DOCTOR_ONLY)
        if restricted:
            raise errors.forbidden("Only a doctor can record this information.")
    latest = latest_facts(db, patient.id)
    now = datetime.now(timezone.utc)
    changed = []
    for key, raw in body.values.items():
        spec = pf.BY_KEY[key]
        try:
            value = spec.validate(raw)
        except ValueError as exc:
            raise errors.unprocessable(str(exc), {"field": key})
        previous = latest.get(key)
        # Re-confirming an unchanged answer still records it, so its freshness is renewed.
        db.add(HealthFact(patient_id=patient.id, field=key, value=value, recorded_at=now, recorded_by_user_id=current.id, recorded_by_role=current.role))
        if previous is None or previous.value != value:
            changed.append(key)
    audit(db, current, "health_profile_updated", "patient", patient.id, patient.patient_code, {"fields": sorted(body.values), "changed": changed})
    db.commit()
    return _profile_out(db, patient)


def _report_for(db: Session, current: CurrentUser, report_id: str) -> tuple[Report, Any]:
    report = db.get(Report, report_id)
    if report is None:
        raise errors.not_found("Report")
    patient = authorize_patient(db, current, report.patient_id)
    return report, patient


def _value_out(v: ReportValue) -> dict:
    analyte = rv.ANALYTES.get(v.analyte)
    return {
        "id": v.id, "analyte": v.analyte, "label": analyte.label if analyte else v.analyte, "value": v.value, "text_value": v.text_value,
        "unit": v.unit, "entered_value": v.entered_value, "entered_unit": v.entered_unit, "measured_on": iso(v.measured_on),
        "origin": v.origin, "confirmed_by_role": v.confirmed_by_role, "confirmed_at": iso(v.confirmed_at),
        # Read automatically and not yet checked by the patient or a doctor.
        "needs_check": v.confirmed_by_role == AUTOMATIC,
    }


def _values_out(db: Session, report: Report) -> dict:
    active = rv.active_values(db, report_id=report.id)
    confirmed = {v.analyte: v for v in active}
    summary = rv.latest_report_summary(db, report.id)
    suggestions = []
    if summary is not None:
        for s in rv.suggestions_from_summary(summary.content or {}):
            existing = confirmed.get(s["analyte"])
            if existing is None or existing.value != s["value"]:
                suggestions.append({**s, "label": rv.ANALYTES[s["analyte"]].label, "ai_summary_id": summary.id})
    return {
        "report_id": report.id, "report_code": report.report_code, "report_date": iso(report.report_date),
        "extraction": {"at": iso(report.values_extracted_at), "note": report.values_extraction_note},
        "values": [_value_out(confirmed[a]) for a in rv.ANALYTES if a in confirmed],
        "suggestions": suggestions,
        "analytes": [
            {"key": a.key, "label": a.label, "kind": a.kind, "unit": a.unit, "units": rv.unit_options(a),
             "options": [{"value": v, "label": label} for v, label in a.options]}
            for a in rv.ANALYTES.values()
        ],
    }


@router.post("/reports/{report_id}/values/read")
def read_report_values(report_id: str, current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    """Reads HbA1c / glucose results from the report file again (e.g. reports uploaded earlier)."""
    report, patient = _report_for(db, current, report_id)
    data = get_storage().read(report.storage_ref)
    stored = extract_from_text(db, report, data)
    if not stored and needs_ai(report):
        try:
            stored = extract_with_ai(db, report, data)
        except errors.ApiError:
            report.values_extraction_note = "The AI reader isn't available right now. You can add the values yourself."
    audit(db, current, "report_values_read", "report", report.id, report.report_code, {"patient_code": patient.patient_code, "values": stored})
    db.commit()
    return _values_out(db, report)


@router.get("/reports/{report_id}/values")
def get_report_values(report_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    report, _ = _report_for(db, current, report_id)
    return _values_out(db, report)


@router.put("/reports/{report_id}/values")
def save_report_values(report_id: str, body: ReportValuesIn, current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    report, patient = _report_for(db, current, report_id)
    unknown = sorted(set(body.values) - set(rv.ANALYTES))
    if unknown:
        raise errors.unprocessable("Unknown report value.", {"fields": unknown})
    now = datetime.now(timezone.utc)
    active = {v.analyte: v for v in rv.active_values(db, report_id=report.id)}
    summary = rv.latest_report_summary(db, report.id)
    changed = []
    for key, item in body.values.items():
        analyte = rv.ANALYTES[key]
        existing = active.get(key)
        if item is None:
            if existing is not None:  # correction: the report does not contain this value
                existing.superseded_at = now
                db.add(ReportValue(report_id=report.id, patient_id=patient.id, analyte=key, measured_on=report.report_date, origin="manual",
                                   confirmed_by_user_id=current.id, confirmed_by_role=current.role, confirmed_at=now,
                                   previous_id=existing.id, removed=True, superseded_at=now))
                changed.append(key)
            continue
        if item.origin not in ("manual", "ai_suggestion", "confirm"):
            raise errors.unprocessable("Unknown value origin.", {"field": key})
        if item.origin == "confirm":
            # "Looks right" on a value read automatically: record who checked it.
            if existing is None:
                raise errors.unprocessable("There is no value to confirm.", {"field": key})
            if existing.confirmed_by_role == AUTOMATIC:
                existing.superseded_at = now
                db.add(ReportValue(report_id=report.id, patient_id=patient.id, analyte=key, value=existing.value, text_value=existing.text_value,
                                   unit=existing.unit, entered_value=existing.entered_value, entered_unit=existing.entered_unit,
                                   measured_on=existing.measured_on, origin=existing.origin, confirmed_by_user_id=current.id,
                                   confirmed_by_role=current.role, confirmed_at=now, previous_id=existing.id))
                changed.append(key)
            continue
        row = ReportValue(report_id=report.id, patient_id=patient.id, analyte=key, measured_on=report.report_date, origin=item.origin,
                          ai_summary_id=summary.id if item.origin == "ai_suggestion" and summary else None,
                          confirmed_by_user_id=current.id, confirmed_by_role=current.role, confirmed_at=now,
                          previous_id=existing.id if existing else None)
        if analyte.kind == "classification":
            allowed = [v for v, _ in analyte.options]
            if item.text_value not in allowed:
                raise errors.unprocessable("Choose Normal, Prediabetes or Diabetes, as written in the report.", {"field": key})
            row.text_value = item.text_value
            same = existing is not None and existing.text_value == row.text_value
        else:
            if item.value is None:
                raise errors.unprocessable(f"Enter the {analyte.label} value.", {"field": key})
            try:
                row.value = rv.to_canonical(analyte, item.value, item.unit if item.unit is not None else (analyte.unit if analyte.unit == "%" else None))
            except ValueError as exc:
                raise errors.unprocessable(str(exc), {"field": key})
            row.unit, row.entered_value, row.entered_unit = analyte.unit, float(item.value), item.unit or analyte.unit
            same = existing is not None and existing.value == row.value
        if same and existing.confirmed_by_role != AUTOMATIC:
            continue  # nothing changed; keep the original confirmation
        if existing is not None:
            existing.superseded_at = now
        db.add(row)
        changed.append(key)
    if changed:
        audit(db, current, "report_values_confirmed", "report", report.id, report.report_code, {"patient_code": patient.patient_code, "values": changed})
    db.commit()
    return _values_out(db, report)

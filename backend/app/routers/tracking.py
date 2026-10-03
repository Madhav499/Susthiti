"""Glucose, food, lifestyle metrics and wearable devices."""

from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, current_patient, require_clinical, require_record_reader, require_patient
from ..models import FoodEntry, GlucoseReading, LifestyleMetric, WearableConnection, utcnow
from ..schemas import (
    FoodIn,
    GlucoseIn,
    LifestyleIn,
    WearableConnectIn,
    WearableSyncIn,
    food_out,
    glucose_out,
    metric_out,
    wearable_out,
)
from ..services.lifestyle_data import food_overview, glucose_overview, metric_overview
from ..services.records import audit
from ..services.wearables import METRIC_UNITS, PROVIDERS, SyncError, available_providers, sync_connection, validate_metric

router = APIRouter(tags=["tracking"])


def _day_bounds(start: date | None, end: date | None):
    lo = datetime(start.year, start.month, start.day, tzinfo=timezone.utc) if start else None
    hi = datetime(end.year, end.month, end.day, tzinfo=timezone.utc) + timedelta(days=1) if end else None
    return lo, hi


# ---------- Glucose ----------

@router.post("/patients/{patient_id}/glucose", status_code=201)
def add_glucose(patient_id: str, body: GlucoseIn, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    reading = GlucoseReading(patient_id=patient.id, recorded_by_user_id=current.id, **body.model_dump())
    db.add(reading)
    db.commit()
    return glucose_out(reading)


@router.get("/patients/{patient_id}/glucose")
def list_glucose(
    patient_id: str, start: date | None = None, end: date | None = None,
    reading_type: str | None = None, limit: int = Query(50, ge=1, le=500), offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    query = select(GlucoseReading).where(GlucoseReading.patient_id == patient.id)
    lo, hi = _day_bounds(start, end)
    if lo:
        query = query.where(GlucoseReading.measured_at >= lo)
    if hi:
        query = query.where(GlucoseReading.measured_at < hi)
    if reading_type:
        query = query.where(GlucoseReading.reading_type == reading_type)
    total = db.scalar(select(func.count()).select_from(query.subquery()))
    rows = db.scalars(query.order_by(GlucoseReading.measured_at.desc()).limit(limit).offset(offset))
    return {"items": [glucose_out(r) for r in rows], "total": total}


@router.get("/patients/{patient_id}/glucose/overview")
def glucose_summary(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    return glucose_overview(db, authorize_patient(db, current, patient_id).id)


# ---------- Food ----------

@router.post("/patients/{patient_id}/food", status_code=201)
def add_food(patient_id: str, body: FoodIn, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    entry = FoodEntry(patient_id=patient.id, recorded_by_user_id=current.id, **body.model_dump())
    db.add(entry)
    db.commit()
    return food_out(entry)


@router.put("/food/{entry_id}")
def edit_food(entry_id: str, body: FoodIn, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    """Editing keeps history: a new revision is created and the old one is marked superseded."""
    old = db.get(FoodEntry, entry_id)
    if old is None:
        raise errors.not_found("Food entry")
    authorize_patient(db, current, old.patient_id)
    if old.superseded_at is not None:
        raise errors.conflict("This entry has already been edited. Refresh to see the latest version.")
    new = FoodEntry(patient_id=old.patient_id, recorded_by_user_id=current.id, previous_id=old.id, **body.model_dump())
    old.superseded_at = utcnow()
    db.add(new)
    db.commit()
    return food_out(new)


@router.get("/food/{entry_id}/history")
def food_history(entry_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    entry = db.get(FoodEntry, entry_id)
    if entry is None:
        raise errors.not_found("Food entry")
    authorize_patient(db, current, entry.patient_id)
    chain = [entry]
    while chain[-1].previous_id:
        chain.append(db.get(FoodEntry, chain[-1].previous_id))
    return {"items": [food_out(e) for e in chain]}


@router.get("/patients/{patient_id}/food")
def list_food(
    patient_id: str, start: date | None = None, end: date | None = None,
    limit: int = Query(100, ge=1, le=500), offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    query = select(FoodEntry).where(FoodEntry.patient_id == patient.id, FoodEntry.superseded_at.is_(None))
    lo, hi = _day_bounds(start, end)
    if lo:
        query = query.where(FoodEntry.eaten_at >= lo)
    if hi:
        query = query.where(FoodEntry.eaten_at < hi)
    rows = db.scalars(query.order_by(FoodEntry.eaten_at.desc()).limit(limit).offset(offset))
    return {"items": [food_out(r) for r in rows]}


# ---------- Lifestyle ----------

@router.post("/patients/{patient_id}/lifestyle", status_code=201)
def add_metric(patient_id: str, body: LifestyleIn, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    problem = validate_metric(body.metric_type, body.value, body.value2)
    if problem:
        raise errors.unprocessable(problem, {"field": "value"})
    metric = LifestyleMetric(
        patient_id=patient.id, metric_type=body.metric_type, value=body.value, value2=body.value2,
        unit=METRIC_UNITS[body.metric_type], recorded_at=body.recorded_at,
        local_date=body.local_date or body.recorded_at.date(), source="manual",
    )
    db.add(metric)
    db.commit()
    return metric_out(metric)


@router.get("/patients/{patient_id}/lifestyle/overview")
def lifestyle_overview(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    metrics = {m: metric_overview(db, patient.id, m) for m in ("steps", "heart_rate", "sleep", "activity", "blood_pressure", "spo2")}
    return {
        "metrics": metrics,
        "glucose": glucose_overview(db, patient.id),
        "food": {k: v for k, v in food_overview(db, patient.id, days=1).items() if k != "entries"},
        "devices": [wearable_out(w) for w in db.scalars(select(WearableConnection).where(WearableConnection.patient_id == patient.id, WearableConnection.status != "disconnected"))],
    }


# ---------- Wearables ----------

@router.get("/wearables/providers")
def providers(current: CurrentUser = Depends(require_patient)):
    return {"items": [
        {"id": p.id, "name": p.name, "description": p.description, "on_device": p.on_device, "supported_metrics": list(p.supported_metrics), "is_demo": p.is_demo}
        for p in available_providers()
    ]}


@router.get("/wearables")
def my_devices(current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    patient = current_patient(db, current)
    rows = db.scalars(select(WearableConnection).where(WearableConnection.patient_id == patient.id, WearableConnection.status != "disconnected").order_by(WearableConnection.created_at.desc()))
    return {"items": [wearable_out(w) for w in rows]}


@router.post("/wearables/connect", status_code=201)
def connect(body: WearableConnectIn, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    patient = current_patient(db, current)
    provider = PROVIDERS.get(body.provider)
    if provider is None or provider not in available_providers():
        raise errors.unprocessable("This device type isn't supported.")
    existing = db.scalar(select(WearableConnection).where(WearableConnection.patient_id == patient.id, WearableConnection.provider == provider.id, WearableConnection.status != "disconnected"))
    if existing:
        if body.granted_metrics is not None:
            existing.granted_metrics = sorted(m for m in set(body.granted_metrics) if m in provider.supported_metrics)
            db.commit()
        return wearable_out(existing)
    granted = None if body.granted_metrics is None else sorted(m for m in set(body.granted_metrics) if m in provider.supported_metrics)
    connection = WearableConnection(
        patient_id=patient.id, provider=provider.id, device_name=provider.name, status="connected",
        supported_metrics=list(provider.supported_metrics), granted_metrics=granted, platform=body.platform, is_demo=provider.is_demo,
    )
    db.add(connection)
    db.flush()
    audit(db, current, "wearable_connected", "wearable", connection.id, provider.id)
    db.commit()
    return wearable_out(connection)


def _own_connection(db: Session, current: CurrentUser, connection_id: str) -> WearableConnection:
    connection = db.get(WearableConnection, connection_id)
    if connection is None or connection.patient_id != current_patient(db, current).id:
        raise errors.not_found("Device")
    return connection


@router.post("/wearables/{connection_id}/sync")
def sync(connection_id: str, body: WearableSyncIn | None = None, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    connection = _own_connection(db, current, connection_id)
    if connection.status == "disconnected":
        raise errors.conflict("This device is disconnected.")
    try:
        result = sync_connection(db, connection, body.samples if body else None, body.granted_metrics if body else None)
    except (SyncError, KeyError, ValueError, TypeError) as exc:
        db.rollback()
        connection = _own_connection(db, current, connection_id)
        connection.status = "sync_failed"
        connection.last_error = str(exc) if isinstance(exc, SyncError) else "The device sent data SUSTHITI couldn't read."
        db.commit()
        return {"device": wearable_out(connection), "imported": 0, "updated": 0, "duplicates": 0, "skipped": 0, "up_to_date": False}
    db.commit()
    return {
        "device": wearable_out(connection), "imported": result.imported, "updated": result.updated,
        "duplicates": result.duplicates, "skipped": result.skipped, "up_to_date": result.up_to_date,
    }


@router.post("/wearables/{connection_id}/disconnect")
def disconnect(connection_id: str, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    """Disconnecting stops future syncs. Previously synced data stays in the history."""
    connection = _own_connection(db, current, connection_id)
    connection.status = "disconnected"
    connection.disconnected_at = utcnow()
    audit(db, current, "wearable_disconnected", "wearable", connection.id, connection.provider)
    db.commit()
    return wearable_out(connection)

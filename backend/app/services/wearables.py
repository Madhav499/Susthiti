"""WearableService.

Two kinds of providers:
- On-device providers (Android Health Connect, Apple Health): the Flutter app reads samples
  on the phone and uploads them with the sync call. The server never invents values, stores
  each measurement once (see dedupe_key) and keeps its measurement time separate from the time
  it was synced. These values carry source "health_platform".
- The DEMO provider (development only, ENABLE_DEMO_WEARABLE=true): generates clearly
  labelled demo samples (is_demo = true) so the flow can be exercised without a watch.
  Demo values are shown with a DEMO badge everywhere and excluded from AI analysis.
"""

import random
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import get_settings
from ..models import LifestyleMetric, WearableConnection, utcnow

METRIC_UNITS = {
    "steps": "steps",
    "heart_rate": "bpm",
    "sleep": "min",
    "activity": "min",
    "blood_pressure": "mmHg",
    "spo2": "%",
    "calories": "kcal",
}

# Plausibility limits used for validation of any lifestyle value (manual or device).
METRIC_LIMITS = {
    "steps": (0, 100000),
    "heart_rate": (20, 250),
    "sleep": (0, 1440),
    "activity": (0, 1440),
    "blood_pressure": (50, 260),  # systolic; diastolic checked separately
    "spo2": (50, 100),
    "calories": (0, 10000),
}


@dataclass(frozen=True)
class Provider:
    id: str
    name: str
    description: str
    on_device: bool
    supported_metrics: tuple[str, ...]
    is_demo: bool = False


PROVIDERS = {
    "health_connect": Provider(
        "health_connect", "Android Health Connect",
        "Reads steps, heart rate, sleep, activity, SpO₂ and blood pressure (where your watch records them) from Health Connect on your phone.",
        True, ("steps", "heart_rate", "sleep", "activity", "spo2", "blood_pressure", "calories"),
    ),
    "apple_health": Provider(
        "apple_health", "Apple Health",
        "Reads steps, heart rate, sleep, activity, SpO₂ and blood pressure (where available) from Apple Health on your iPhone.",
        True, ("steps", "heart_rate", "sleep", "activity", "spo2", "blood_pressure", "calories"),
    ),
    "demo": Provider(
        "demo", "Demo device (DEMO data)",
        "Development only. Generates clearly labelled demo data to try the sync flow. Not real health data.",
        False, ("steps", "heart_rate", "sleep", "activity", "spo2"), is_demo=True,
    ),
}


def available_providers() -> list[Provider]:
    return [p for p in PROVIDERS.values() if not p.is_demo or get_settings().enable_demo_wearable]


def validate_metric(metric_type: str, value: float, value2: float | None) -> str | None:
    if metric_type not in METRIC_LIMITS:
        return f"Unsupported metric: {metric_type}"
    low, high = METRIC_LIMITS[metric_type]
    if not low <= value <= high:
        return f"{metric_type} value must be between {low} and {high}."
    if metric_type == "blood_pressure":
        if value2 is None or not 30 <= value2 <= 200 or value2 >= value:
            return "Blood pressure needs a diastolic value lower than the systolic value."
    return None


class SyncError(Exception):
    pass


@dataclass
class SyncResult:
    imported: int = 0  # new measurements stored
    updated: int = 0  # daily totals refreshed for a day already synced
    duplicates: int = 0  # already stored, skipped
    skipped: int = 0  # unsupported, implausible, not granted or in the future

    @property
    def up_to_date(self) -> bool:
        return self.imported == 0 and self.updated == 0


FUTURE_TOLERANCE = timedelta(minutes=10)


def _parse_time(value) -> datetime:
    """Stored in UTC (SQLite keeps no offset), so 10:32 in India is saved as 05:02Z, not 10:32Z."""
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    return (parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)).astimezone(timezone.utc)


def dedupe_key(provider: str, sample: dict, metric: str, recorded_at: datetime, local_day: date | None) -> str:
    """The same measurement always gets the same key, so re-syncing never stores it twice.
    Daily totals: one per source, metric and day. Readings: the platform's record id when it
    gives one, otherwise source + metric + measurement time + value."""
    if sample.get("daily_total") and local_day is not None:
        return f"{provider}:{metric}:day:{local_day.isoformat()}"
    external = str(sample.get("external_id") or "").strip()
    if external:
        return f"{provider}:{metric}:id:{external[:120]}"
    return f"{provider}:{metric}:{recorded_at.isoformat()}:{float(sample['value'])}:{sample.get('value2')}"


def sync_connection(db: Session, connection: WearableConnection, samples: list[dict] | None, granted: list[str] | None = None) -> SyncResult:
    provider = PROVIDERS[connection.provider]
    if granted is not None:
        connection.granted_metrics = sorted(m for m in set(granted) if m in provider.supported_metrics)
    now = utcnow()
    result = SyncResult()
    if provider.is_demo:
        rows = _demo_samples(db, connection)
        for row in rows:
            row.synced_at = now
            db.add(row)
        result.imported = len(rows)
    else:
        if samples is None:
            raise SyncError("No data was received from the device. Open SUSTHITI on your phone and allow health data access, then try again.")
        allowed = set(connection.granted_metrics if connection.granted_metrics is not None else provider.supported_metrics)
        prepared: dict[str, tuple[dict, str, datetime, date | None]] = {}
        for sample in samples:
            metric = sample.get("metric_type")
            if metric not in provider.supported_metrics or metric not in allowed:
                result.skipped += 1
                continue
            value = float(sample["value"])
            value2 = sample.get("value2")
            recorded_at = _parse_time(sample["recorded_at"])
            if validate_metric(metric, value, value2) or recorded_at > now + FUTURE_TOLERANCE:
                result.skipped += 1
                continue
            local_day = date.fromisoformat(sample["local_date"]) if sample.get("local_date") else None
            key = dedupe_key(provider.id, sample, metric, recorded_at, local_day)
            prepared[key] = (sample, metric, recorded_at, local_day)  # last one wins within a batch
        existing = {}
        if prepared:
            query = select(LifestyleMetric).where(LifestyleMetric.patient_id == connection.patient_id, LifestyleMetric.dedupe_key.in_(list(prepared)))
            for row in db.scalars(query):
                existing[row.dedupe_key] = row
        for key, (sample, metric, recorded_at, local_day) in prepared.items():
            value = float(sample["value"])
            value2 = None if sample.get("value2") is None else float(sample["value2"])
            started_at = _parse_time(sample["started_at"]) if sample.get("started_at") else None
            row = existing.get(key)
            if row is not None:
                if sample.get("daily_total") and (row.value, row.value2) != (value, value2):
                    row.value, row.value2, row.recorded_at, row.started_at, row.synced_at = value, value2, recorded_at, started_at, now
                    result.updated += 1
                else:
                    result.duplicates += 1
                continue
            db.add(LifestyleMetric(
                patient_id=connection.patient_id, metric_type=metric, value=value, value2=value2,
                unit=METRIC_UNITS[metric], recorded_at=recorded_at, started_at=started_at, local_date=local_day,
                source="health_platform", dedupe_key=key, synced_at=now,
                wearable_connection_id=connection.id, is_demo=False,
            ))
            result.imported += 1
    connection.status = "connected"
    connection.last_error = None
    connection.last_synced_at = now
    return result


def _demo_samples(db: Session, connection: WearableConnection) -> list[LifestyleMetric]:
    """DEMO data only: one daily value per metric for the last 7 days not already generated."""
    today = datetime.now(timezone.utc).date()
    existing_days = {
        m.recorded_at.date()
        for m in db.scalars(
            select(LifestyleMetric).where(
                LifestyleMetric.wearable_connection_id == connection.id, LifestyleMetric.metric_type == "steps"
            )
        )
    }
    rng = random.Random(connection.id)
    rows = []
    for offset in range(6, -1, -1):
        day = today - timedelta(days=offset)
        if day in existing_days:
            continue
        stamp = datetime.combine(day, time(20, 0), tzinfo=timezone.utc)
        values = {
            "steps": rng.randint(3500, 10500),
            "heart_rate": rng.randint(64, 88),
            "sleep": rng.randint(330, 480),
            "activity": rng.randint(10, 60),
            "spo2": rng.randint(95, 99),
        }
        for metric, value in values.items():
            rows.append(
                LifestyleMetric(
                    patient_id=connection.patient_id, metric_type=metric, value=value, unit=METRIC_UNITS[metric],
                    recorded_at=stamp, local_date=day, source="device", wearable_connection_id=connection.id, is_demo=True,
                    dedupe_key=f"demo:{connection.id}:{metric}:{day.isoformat()}",
                )
            )
    return rows

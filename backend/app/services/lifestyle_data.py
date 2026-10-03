"""Aggregations over recorded data. Never fills gaps with invented values."""

from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from statistics import mean

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import FoodEntry, GlucoseReading, LifestyleMetric
from .health_data.body import local_today, to_local_date

SUM_METRICS = {"steps", "activity", "calories", "sleep"}
MIN_DAYS_FOR_COMPARISON = 5


def _start_of(day: date) -> datetime:
    return datetime(day.year, day.month, day.day, tzinfo=timezone.utc)


def _day(dt: datetime) -> date:
    return to_local_date(dt)


def _aware(dt: datetime | None) -> datetime | None:
    return None if dt is None else (dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc))


def _iso(dt: datetime | None) -> str | None:
    return None if dt is None else dt.isoformat()


def daily_series(db: Session, patient_id: str, metric: str, start: date, end: date, include_demo: bool = True) -> list[dict]:
    query = select(LifestyleMetric).where(
        LifestyleMetric.patient_id == patient_id,
        LifestyleMetric.metric_type == metric,
        # One day of slack either side so rows bucketed by the patient's local date are included.
        LifestyleMetric.recorded_at >= _start_of(start - timedelta(days=1)),
        LifestyleMetric.recorded_at < _start_of(end + timedelta(days=2)),
    ).order_by(LifestyleMetric.recorded_at)
    if not include_demo:
        query = query.where(LifestyleMetric.is_demo.is_(False))
    buckets: dict[date, list[LifestyleMetric]] = defaultdict(list)
    for row in db.scalars(query):
        # Health-platform values and dated manual entries carry their own local_date; anything
        # older falls back to recorded_at's local calendar date.
        day = row.local_date or _day(row.recorded_at)
        if start <= day <= end:
            buckets[day].append(row)
    series = []
    for day in sorted(buckets):
        rows = buckets[day]
        # Real readings replace DEMO values for that day; the two are never added together.
        rows = [r for r in rows if not r.is_demo] or rows
        if metric in SUM_METRICS:
            value, value2 = sum(r.value for r in rows), None
        elif metric == "blood_pressure":
            value, value2 = rows[-1].value, rows[-1].value2
        else:
            value, value2 = round(mean(r.value for r in rows), 1), None
        series.append({
            "date": day.isoformat(), "value": value, "value2": value2,
            "sources": sorted({r.source for r in rows}),
            "last_synced_at": _iso(max((_aware(r.synced_at or r.created_at) for r in rows if r.source != "manual"), default=None)),
            "is_demo": any(r.is_demo for r in rows), "source": rows[-1].source,
        })
    return series


def metric_overview(db: Session, patient_id: str, metric: str, today: date | None = None, include_demo: bool = True) -> dict:
    today = today or local_today()
    series = daily_series(db, patient_id, metric, today - timedelta(days=29), today, include_demo)
    latest = series[-1] if series else None
    previous = [p["value"] for p in series if p["date"] != today.isoformat()][-14:]
    comparison = None
    if latest and latest["date"] == today.isoformat() and len(previous) >= MIN_DAYS_FOR_COMPARISON:
        average = mean(previous)
        if average:
            comparison = {"recent_average": round(average, 1), "change_percent": round((latest["value"] - average) / average * 100), "days": len(previous)}
    return {"metric": metric, "latest": latest, "comparison": comparison, "last_7_days": [p for p in series if p["date"] >= (today - timedelta(days=6)).isoformat()]}


def to_mg_dl(value: float, unit: str) -> float:
    return value if unit == "mg/dL" else round(value * 18.0182, 1)


def glucose_overview(db: Session, patient_id: str, today: date | None = None) -> dict:
    today = today or local_today()
    rows = list(db.scalars(
        select(GlucoseReading).where(GlucoseReading.patient_id == patient_id, GlucoseReading.measured_at >= _start_of(today - timedelta(days=29))).order_by(GlucoseReading.measured_at)
    ))
    today_rows = [r for r in rows if _day(r.measured_at) == today]
    week = [to_mg_dl(r.value, r.unit) for r in rows if _day(r.measured_at) >= today - timedelta(days=6)]
    prior = [to_mg_dl(r.value, r.unit) for r in rows if today - timedelta(days=29) <= _day(r.measured_at) < today - timedelta(days=6)]
    trend = None
    if len(week) >= 3 and len(prior) >= 3:
        delta = mean(week) - mean(prior)
        trend = "stable" if abs(delta) < 5 else ("higher" if delta > 0 else "lower")
    latest = rows[-1] if rows else None
    return {
        "unit": "mg/dL",
        "today_count": len(today_rows),
        "today": [{"value": to_mg_dl(r.value, r.unit), "reading_type": r.reading_type, "measured_at": r.measured_at.isoformat()} for r in today_rows],
        "latest": None if latest is None else {"value": to_mg_dl(latest.value, latest.unit), "reading_type": latest.reading_type, "measured_at": latest.measured_at.isoformat()},
        "recent_average_7d": round(mean(week), 1) if week else None,
        "readings_7d": len(week),
        "trend_vs_previous_weeks": trend,
    }


def food_overview(db: Session, patient_id: str, days: int = 7) -> dict:
    since = _start_of(local_today() - timedelta(days=days - 1))
    rows = list(db.scalars(select(FoodEntry).where(FoodEntry.patient_id == patient_id, FoodEntry.superseded_at.is_(None), FoodEntry.eaten_at >= since).order_by(FoodEntry.eaten_at)))
    return {
        "entries_count": len(rows),
        "days_with_entries": len({_day(r.eaten_at) for r in rows}),
        "entries": [{"food": r.food_name, "quantity": r.quantity, "meal": r.meal_type, "time": r.eaten_at.isoformat()} for r in rows[-60:]],
    }


def lifestyle_snapshot(db: Session, patient_id: str, include_demo: bool = False) -> dict:
    """Compact, real-data-only context stored with assessments and sent to Lifestyle AI."""
    snapshot = {}
    for metric in ("steps", "sleep", "activity", "heart_rate", "spo2", "blood_pressure"):
        overview = metric_overview(db, patient_id, metric, include_demo=include_demo)
        if overview["last_7_days"]:
            values = [p["value"] for p in overview["last_7_days"]]
            snapshot[metric] = {"days_recorded_7d": len(values), "average_7d": round(mean(values), 1), "latest": overview["latest"]}
    glucose = glucose_overview(db, patient_id)
    if glucose["readings_7d"]:
        snapshot["glucose"] = {k: glucose[k] for k in ("recent_average_7d", "readings_7d", "trend_vs_previous_weeks", "unit")}
    food = food_overview(db, patient_id)
    if food["entries_count"]:
        snapshot["food"] = {"entries_7d": food["entries_count"], "days_logged_7d": food["days_with_entries"]}
    return snapshot

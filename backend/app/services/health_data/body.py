"""Height, weight and BMI from the health profile. BMI is always calculated here, from the latest
height and weight (never typed in), so the patient, their doctor and the admin see one value."""

from datetime import date, datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import HealthFact
from ...schemas import iso


def bmi_of(height_cm: float | None, weight_kg: float | None) -> float | None:
    if not height_cm or not weight_kg or height_cm <= 0 or weight_kg <= 0:
        return None
    return round(weight_kg / ((height_cm / 100) ** 2), 1)


def body_measurements(db: Session, patient_id: str) -> dict:
    latest: dict[str, HealthFact] = {}
    for fact in db.scalars(select(HealthFact).where(HealthFact.patient_id == patient_id, HealthFact.field.in_(["height_cm", "weight_kg"]))
                           .order_by(HealthFact.recorded_at)):
        latest[fact.field] = fact
    height = latest.get("height_cm")
    weight = latest.get("weight_kg")
    h = height.value if height and isinstance(height.value, (int, float)) else None
    w = weight.value if weight and isinstance(weight.value, (int, float)) else None
    return {
        "height_cm": h, "weight_kg": w, "bmi": bmi_of(h, w),
        "height_recorded_at": iso(height.recorded_at) if height else None,
        "weight_recorded_at": iso(weight.recorded_at) if weight else None,
    }


def is_birthday(dob: date | None, today: date) -> bool:
    """29 February birthdays are celebrated on 28 February in other years."""
    if dob is None:
        return False
    if (dob.month, dob.day) == (today.month, today.day):
        return True
    leap = today.year % 4 == 0 and (today.year % 100 != 0 or today.year % 400 == 0)
    return (dob.month, dob.day) == (2, 29) and not leap and (today.month, today.day) == (2, 28)


def to_local_datetime(dt: datetime) -> datetime:
    """The full local-timezone instant (date and time) for dt."""
    from zoneinfo import ZoneInfo

    from ...config import get_settings

    aware = dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
    return aware.astimezone(ZoneInfo(get_settings().local_timezone))


def to_local_date(dt: datetime) -> date:
    """The calendar date in LOCAL_TIMEZONE (default India) for an instant. Daily buckets --
    lifestyle metrics, reminders, birthdays -- follow this date, never the UTC date, so the
    patient's day lines up with where they actually are."""
    return to_local_datetime(dt).date()


def local_today() -> date:
    """Today's date where SUSTHITI's patients are (LOCAL_TIMEZONE, default India)."""
    return to_local_date(datetime.now(timezone.utc))

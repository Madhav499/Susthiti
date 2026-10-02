"""SUSTHITI's central health-data layer.

Everything a risk model needs about a patient is read here, from the records SUSTHITI already
keeps: the patient profile, the health profile (body measurements, medical and family history,
habits, recent symptoms), values confirmed from uploaded reports, and lifestyle data from the
phone's health platform or manual logs. build_snapshot() turns it into a PatientHealthSnapshot:
the patient's current known state, with where every value came from and how recent it is.

Nothing here is specific to one model; the diabetes risk feature builder is one consumer.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import HealthFact


def latest_facts(db: Session, patient_id: str) -> dict[str, HealthFact]:
    """The current value of every health-profile field ever recorded for this patient
    (the latest row per field key; HealthFact is append-only)."""
    latest: dict[str, HealthFact] = {}
    for fact in db.scalars(select(HealthFact).where(HealthFact.patient_id == patient_id).order_by(HealthFact.recorded_at)):
        latest[fact.field] = fact
    return latest

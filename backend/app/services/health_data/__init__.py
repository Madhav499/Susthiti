"""SUSTHITI's central health-data layer.

Everything a risk model needs about a patient is read here, from the records SUSTHITI already
keeps: the patient profile, the health profile (body measurements, medical and family history,
habits, recent symptoms), values confirmed from uploaded reports, and lifestyle data from the
phone's health platform or manual logs. build_snapshot() turns it into a PatientHealthSnapshot:
the patient's current known state, with where every value came from and how recent it is.

Nothing here is specific to one model; the diabetes risk feature builder is one consumer.
"""

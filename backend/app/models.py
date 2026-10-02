"""Database tables.

Longitudinal principle: medical records (reports, assessments, glucose, food, lifestyle,
side effects, responses, prescriptions, visits, AI summaries) are append-only. Nothing in
the API updates or deletes them in place; corrections create a new row that references
the previous one.

One narrow exception: a health platform's running *daily total* (steps, sleep, activity,
calories for one day from one source) is refreshed by later syncs of that same day, with
synced_at recording when. Individual readings and manual entries are never changed.
"""

import uuid
from datetime import date, datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def new_id() -> str:
    return uuid.uuid4().hex


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, nullable=False)


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(16), index=True)  # patient | doctor | admin
    full_name: Mapped[str] = mapped_column(String(200))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_demo: Mapped[bool] = mapped_column(Boolean, default=False)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    patient: Mapped["Patient | None"] = relationship(back_populates="user", uselist=False)
    doctor: Mapped["Doctor | None"] = relationship(back_populates="user", uselist=False)


class AuthSession(Base, TimestampMixin):
    __tablename__ = "auth_sessions"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)  # JWT jti
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class PasswordResetToken(Base, TimestampMixin):
    __tablename__ = "password_reset_tokens"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    token_hash: Mapped[str] = mapped_column(String(128), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Patient(Base, TimestampMixin):
    __tablename__ = "patients"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True)
    patient_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    date_of_birth: Mapped[date | None] = mapped_column(Date)
    gender: Mapped[str | None] = mapped_column(String(16))
    phone: Mapped[str | None] = mapped_column(String(32))
    photo_ref: Mapped[str | None] = mapped_column(String(255))
    emergency_name: Mapped[str | None] = mapped_column(String(200))
    emergency_relationship: Mapped[str | None] = mapped_column(String(100))
    emergency_phone: Mapped[str | None] = mapped_column(String(32))

    user: Mapped[User] = relationship(back_populates="patient")


class Doctor(Base, TimestampMixin):
    __tablename__ = "doctors"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), unique=True)
    doctor_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    specialization: Mapped[str | None] = mapped_column(String(120))
    license_number: Mapped[str | None] = mapped_column(String(80))
    phone: Mapped[str | None] = mapped_column(String(32))

    user: Mapped[User] = relationship(back_populates="doctor")


class AccessRequest(Base, TimestampMixin):
    __tablename__ = "access_requests"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    doctor_id: Mapped[str] = mapped_column(ForeignKey("doctors.id"), index=True)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    status: Mapped[str] = mapped_column(String(16), default="pending", index=True)
    message: Mapped[str | None] = mapped_column(Text)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    revoked_by_user_id: Mapped[str | None] = mapped_column(String(32))

    doctor: Mapped[Doctor] = relationship()
    patient: Mapped[Patient] = relationship()


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    report_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    category: Mapped[str] = mapped_column(String(40), index=True)
    report_date: Mapped[date] = mapped_column(Date, index=True)  # medical event date
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)  # upload event
    uploaded_by_role: Mapped[str] = mapped_column(String(16))
    uploader_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    uploader_name: Mapped[str] = mapped_column(String(200))
    original_filename: Mapped[str] = mapped_column(String(255))
    file_type: Mapped[str] = mapped_column(String(100))
    file_size: Mapped[int] = mapped_column(Integer)
    storage_ref: Mapped[str] = mapped_column(String(255))  # opaque key, never a public URL
    sha256: Mapped[str] = mapped_column(String(64))
    description: Mapped[str | None] = mapped_column(Text)
    # Every type the report covers (a full body checkup is also a blood report, an HbA1c...).
    # `category` stays the first one, for filters and older records.
    categories: Mapped[list | None] = mapped_column(JSON)
    # Automatic reading of diabetes values from the file: when, and what happened.
    values_extracted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    values_extraction_note: Mapped[str | None] = mapped_column(Text)


class AISummary(Base):
    """Every AI generation is stored as a new row (regenerating never overwrites)."""

    __tablename__ = "ai_summaries"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    # individual_report | all_reports | patient_summary | lifestyle | assessment_interpretation
    kind: Mapped[str] = mapped_column(String(40), index=True)
    subject_id: Mapped[str | None] = mapped_column(String(32), index=True)  # report or assessment id
    source_ids: Mapped[list] = mapped_column(JSON, default=list)
    source_fingerprint: Mapped[str] = mapped_column(String(64))
    content: Mapped[dict] = mapped_column(JSON)
    provider: Mapped[str] = mapped_column(String(40))
    model: Mapped[str] = mapped_column(String(80))
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    generated_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    generated_by_role: Mapped[str] = mapped_column(String(16))


class DiabetesAssessment(Base):
    """Assessment from the earlier 16-question symptom model (retired). Kept read-only as history;
    new assessments are DiabetesRiskAssessment. Recent answers still count as symptom data."""

    __tablename__ = "diabetes_assessments"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    assessment_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    assessed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    model_version: Mapped[str] = mapped_column(String(80))
    model_name: Mapped[str | None] = mapped_column(String(200))
    inputs: Mapped[dict] = mapped_column(JSON)  # exactly the 16 model features
    prediction: Mapped[str] = mapped_column(String(20))
    # The model's probability for the Positive class, exactly as returned by the diabetes API.
    classification_probability: Mapped[float | None] = mapped_column(Float)
    # The API's own wording, stored as it was shown to the patient at the time.
    interpretation: Mapped[str | None] = mapped_column(Text)
    disclaimer: Mapped[str | None] = mapped_column(Text)
    lifestyle_snapshot: Mapped[dict] = mapped_column(JSON, default=dict)
    performed_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    performed_by_role: Mapped[str] = mapped_column(String(16))


class HealthFact(Base):
    """One answer in the patient's health profile (body measurements, medical and family
    history, habits, recent symptoms). Append-only: a change adds a new row and the latest row
    per field is the current value, so every value keeps who recorded it and when. A value of
    None records an explicit "not sure", which is different from never having been asked.
    Not specific to any model: every risk model reads the same profile."""

    __tablename__ = "health_facts"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    field: Mapped[str] = mapped_column(String(40), index=True)
    value: Mapped[object | None] = mapped_column(JSON)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    recorded_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    recorded_by_role: Mapped[str] = mapped_column(String(16))


class ReportValue(Base):
    """A structured value confirmed from an uploaded report (e.g. HbA1c 6.1 %). Append-only:
    a correction adds a new row pointing at the one it replaces. Every row was confirmed by a
    person (patient or doctor); AI-extracted values are only suggestions until confirmed."""

    __tablename__ = "report_values"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    report_id: Mapped[str] = mapped_column(ForeignKey("reports.id"), index=True)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    # hba1c | fasting_glucose | random_glucose | ogtt_2h | diabetes_classification
    analyte: Mapped[str] = mapped_column(String(40), index=True)
    value: Mapped[float | None] = mapped_column(Float)  # canonical unit: % or mg/dL
    text_value: Mapped[str | None] = mapped_column(String(40))  # Normal | Prediabetes | Diabetes
    unit: Mapped[str | None] = mapped_column(String(16))  # canonical unit stored
    entered_value: Mapped[float | None] = mapped_column(Float)  # as written in the report
    entered_unit: Mapped[str | None] = mapped_column(String(16))
    measured_on: Mapped[date] = mapped_column(Date, index=True)  # the report's date
    origin: Mapped[str] = mapped_column(String(20))  # manual | ai_suggestion
    ai_summary_id: Mapped[str | None] = mapped_column(String(32))
    confirmed_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    confirmed_by_role: Mapped[str] = mapped_column(String(16))
    confirmed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    previous_id: Mapped[str | None] = mapped_column(String(32))
    superseded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    removed: Mapped[bool] = mapped_column(Boolean, default=False)  # "not in this report" correction


class DiabetesRiskAssessment(Base):
    """One model-estimated future diabetes risk from the SUSTHITI Diabetes Risk API (v4).
    Immutable: a refresh creates a new row. Stores exactly what was sent to the model and where
    each value came from, so every result can be reproduced and explained later."""

    __tablename__ = "diabetes_risk_assessments"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    assessment_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    performed_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    performed_by_role: Mapped[str] = mapped_column(String(16))
    # The API's response, as returned.
    model_version: Mapped[str] = mapped_column(String(40))
    risk_percent: Mapped[float] = mapped_column(Float)
    risk_category: Mapped[str] = mapped_column(String(16))
    risk_thresholds: Mapped[dict] = mapped_column(JSON, default=dict)
    prediction: Mapped[int] = mapped_column(Integer)
    prediction_label: Mapped[str] = mapped_column(String(60))
    prediction_threshold: Mapped[str | None] = mapped_column(String(80))
    prediction_basis: Mapped[str] = mapped_column(String(60))
    report_available: Mapped[bool] = mapped_column(Boolean)
    report_fields_present: Mapped[list] = mapped_column(JSON, default=list)
    bmi: Mapped[float | None] = mapped_column(Float)
    warning: Mapped[str | None] = mapped_column(Text)
    # What SUSTHITI sent (only the model's features) and where each value came from.
    input_features: Mapped[dict] = mapped_column(JSON, default=dict)
    provenance: Mapped[list] = mapped_column(JSON, default=list)
    missing_features: Mapped[list] = mapped_column(JSON, default=list)
    # Change detection: a new assessment is only needed when this fingerprint changes.
    input_fingerprint: Mapped[str] = mapped_column(String(64), index=True)
    snapshot_built_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class GlucoseReading(Base, TimestampMixin):
    __tablename__ = "glucose_readings"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    value: Mapped[float] = mapped_column(Float)
    unit: Mapped[str] = mapped_column(String(10))  # mg/dL | mmol/L
    reading_type: Mapped[str] = mapped_column(String(16))  # fasting | post_meal | random
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    source: Mapped[str] = mapped_column(String(16))  # manual | device | imported
    context: Mapped[str | None] = mapped_column(Text)
    recorded_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    is_demo: Mapped[bool] = mapped_column(Boolean, default=False)


class FoodEntry(Base, TimestampMixin):
    """Edits create a new revision; the old one is kept with superseded_at set."""

    __tablename__ = "food_entries"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    food_name: Mapped[str] = mapped_column(String(200))
    quantity: Mapped[str] = mapped_column(String(100))
    meal_type: Mapped[str] = mapped_column(String(16))
    eaten_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    previous_id: Mapped[str | None] = mapped_column(String(32))
    superseded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    recorded_by_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))


class LifestyleMetric(Base, TimestampMixin):
    __tablename__ = "lifestyle_metrics"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    # steps | heart_rate | sleep | activity | blood_pressure | spo2 | calories
    metric_type: Mapped[str] = mapped_column(String(20), index=True)
    value: Mapped[float] = mapped_column(Float)
    value2: Mapped[float | None] = mapped_column(Float)  # diastolic for blood_pressure
    unit: Mapped[str] = mapped_column(String(16))
    # Measurement time (end of the measured window for totals). Never the sync time.
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    # Start of the measured window (sleep session, a day's total), when there is one.
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # The patient's own calendar date for this value (daily buckets follow the patient's day).
    local_date: Mapped[date | None] = mapped_column(Date, index=True)
    source: Mapped[str] = mapped_column(String(16))  # manual | health_platform | device | imported
    # Identifies the same measurement across syncs so it is stored once.
    dedupe_key: Mapped[str | None] = mapped_column(String(200), index=True)
    # When a sync last wrote this row (created_at is when it first arrived).
    synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    wearable_connection_id: Mapped[str | None] = mapped_column(String(32))
    is_demo: Mapped[bool] = mapped_column(Boolean, default=False)


class WearableConnection(Base, TimestampMixin):
    __tablename__ = "wearable_connections"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    provider: Mapped[str] = mapped_column(String(40))
    device_name: Mapped[str] = mapped_column(String(120))
    status: Mapped[str] = mapped_column(String(20))  # connected | sync_failed | disconnected
    last_synced_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_error: Mapped[str | None] = mapped_column(Text)
    supported_metrics: Mapped[list] = mapped_column(JSON, default=list)
    # Metrics the patient actually granted on the phone (None: not reported).
    granted_metrics: Mapped[list | None] = mapped_column(JSON)
    # android | ios, when connected from a phone.
    platform: Mapped[str | None] = mapped_column(String(20))
    is_demo: Mapped[bool] = mapped_column(Boolean, default=False)
    disconnected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class SideEffect(Base, TimestampMixin):
    __tablename__ = "side_effects"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    side_effect_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    description: Mapped[str] = mapped_column(Text)
    severity: Mapped[str] = mapped_column(String(16))  # mild | moderate | severe | emergency
    related_medication: Mapped[str | None] = mapped_column(String(200))
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    notes: Mapped[str | None] = mapped_column(Text)
    # new | under_review | responded | appointment_recommended | resolved
    status: Mapped[str] = mapped_column(String(30), default="new", index=True)
    # Rule-based flag (severity is severe or emergency). Not a clinical judgement.
    priority_flag: Mapped[bool] = mapped_column(Boolean, default=False)


class SideEffectEvent(Base, TimestampMixin):
    """Append-only history of status changes and doctor responses."""

    __tablename__ = "side_effect_events"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    side_effect_id: Mapped[str] = mapped_column(ForeignKey("side_effects.id"), index=True)
    actor_user_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    actor_name: Mapped[str] = mapped_column(String(200))
    actor_role: Mapped[str] = mapped_column(String(16))
    status: Mapped[str] = mapped_column(String(30))
    # no_immediate_action | monitor | contact_doctor | appointment_recommended | urgent_medical_attention
    response_type: Mapped[str | None] = mapped_column(String(40))
    message: Mapped[str | None] = mapped_column(Text)


class AppointmentRecommendation(Base, TimestampMixin):
    __tablename__ = "appointment_recommendations"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    doctor_id: Mapped[str] = mapped_column(ForeignKey("doctors.id"))
    doctor_name: Mapped[str] = mapped_column(String(200))
    side_effect_id: Mapped[str | None] = mapped_column(ForeignKey("side_effects.id"))
    reason: Mapped[str] = mapped_column(Text)
    recommended_for: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Visit(Base, TimestampMixin):
    __tablename__ = "visits"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    visit_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    doctor_id: Mapped[str] = mapped_column(ForeignKey("doctors.id"))
    doctor_name: Mapped[str] = mapped_column(String(200))
    visit_date: Mapped[date] = mapped_column(Date, index=True)
    reason: Mapped[str] = mapped_column(Text)
    clinical_notes: Mapped[str | None] = mapped_column(Text)
    assessment: Mapped[str | None] = mapped_column(Text)
    doctor_reasoning: Mapped[str | None] = mapped_column(Text)
    treatment_decision: Mapped[str | None] = mapped_column(Text)
    follow_up_date: Mapped[date | None] = mapped_column(Date, index=True)
    instructions: Mapped[str | None] = mapped_column(Text)


class Prescription(Base, TimestampMixin):
    __tablename__ = "prescriptions"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    prescription_code: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    patient_id: Mapped[str] = mapped_column(ForeignKey("patients.id"), index=True)
    doctor_id: Mapped[str] = mapped_column(ForeignKey("doctors.id"))
    doctor_name: Mapped[str] = mapped_column(String(200))
    prescribed_on: Mapped[date] = mapped_column(Date, index=True)
    instructions: Mapped[str | None] = mapped_column(Text)
    notes: Mapped[str | None] = mapped_column(Text)
    follow_up_date: Mapped[date | None] = mapped_column(Date, index=True)

    items: Mapped[list["PrescriptionItem"]] = relationship(
        back_populates="prescription", order_by="PrescriptionItem.position"
    )


class PrescriptionItem(Base):
    __tablename__ = "prescription_items"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    prescription_id: Mapped[str] = mapped_column(ForeignKey("prescriptions.id"), index=True)
    position: Mapped[int] = mapped_column(Integer)
    medicine: Mapped[str] = mapped_column(String(200))
    dosage: Mapped[str] = mapped_column(String(100))
    frequency: Mapped[str] = mapped_column(String(100))
    duration: Mapped[str] = mapped_column(String(100))
    instructions: Mapped[str | None] = mapped_column(Text)

    prescription: Mapped[Prescription] = relationship(back_populates="items")


class Notification(Base, TimestampMixin):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    type: Mapped[str] = mapped_column(String(40))
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text)
    entity_type: Mapped[str | None] = mapped_column(String(40))
    entity_id: Mapped[str | None] = mapped_column(String(32))
    patient_id: Mapped[str | None] = mapped_column(String(32))
    dedupe_key: Mapped[str | None] = mapped_column(String(120), index=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class NotificationPreference(Base):
    __tablename__ = "notification_preferences"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    food_reminders: Mapped[bool] = mapped_column(Boolean, default=True)
    lifestyle_reminders: Mapped[bool] = mapped_column(Boolean, default=True)
    follow_up_reminders: Mapped[bool] = mapped_column(Boolean, default=True)
    doctor_notifications: Mapped[bool] = mapped_column(Boolean, default=True)


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(String(32), primary_key=True, default=new_id)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    actor_user_id: Mapped[str | None] = mapped_column(String(32), index=True)
    actor_role: Mapped[str | None] = mapped_column(String(16))
    actor_name: Mapped[str | None] = mapped_column(String(200))
    action: Mapped[str] = mapped_column(String(60), index=True)
    entity_type: Mapped[str | None] = mapped_column(String(40))
    entity_id: Mapped[str | None] = mapped_column(String(32))
    entity_label: Mapped[str | None] = mapped_column(String(120))
    # Non-sensitive context only (ids, codes, statuses). Never medical content.
    details: Mapped[dict] = mapped_column(JSON, default=dict)


class Counter(Base):
    """Monotonic counters for human-readable record codes (P-000001, RX-000001...)."""

    __tablename__ = "counters"

    name: Mapped[str] = mapped_column(String(40), primary_key=True)
    value: Mapped[int] = mapped_column(Integer, default=0)


class SystemSetting(Base):
    __tablename__ = "system_settings"
    __table_args__ = (UniqueConstraint("key"),)

    key: Mapped[str] = mapped_column(String(80), primary_key=True)
    value: Mapped[str] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

"""Request bodies (validated) and response serializers."""

import re
from datetime import date, datetime, timedelta, timezone
from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, Field, field_validator, model_validator

from . import models as m

PHONE_RE = re.compile(r"^\+?[0-9 ()-]{7,20}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
PATIENT_CODE_RE = re.compile(r"^SUS-P-[0-9A-F]{6}$")
_GRACE = timedelta(minutes=5)

ReportCategory = Literal[
    "full_body", "blood_report", "hba1c", "blood_glucose", "lipid_profile", "kidney_function", "liver_function",
    "urine_test", "x_ray", "mri", "ct", "ecg", "other",
]
REPORT_CATEGORIES = ReportCategory.__args__


def _phone(value: str | None) -> str | None:
    if value in (None, ""):
        return None
    if not PHONE_RE.match(value):
        raise ValueError("Enter a valid phone number.")
    return value


def _required_text(value: str, label: str) -> str:
    value = value.strip()
    if len(value) < 3:
        raise ValueError(f"{label} is required.")
    return value


def _email(value: str) -> str:
    # Format check only (matches the app). Deliverability is not checked, so reserved test
    # domains used for DEMO accounts (e.g. susthiti.test) are accepted.
    value = value.strip().lower()
    if len(value) > 254 or not EMAIL_RE.match(value):
        raise ValueError("Enter a valid email address.")
    return value


Email = Annotated[str, AfterValidator(_email)]


def to_utc(value: datetime) -> datetime:
    """All timestamps are stored in UTC; naive values are treated as UTC."""
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _not_future(value: datetime | date | None, label: str):
    if value is None:
        return value
    now = datetime.now(timezone.utc)
    if isinstance(value, datetime):
        aware = to_utc(value)
        if aware > now + _GRACE:
            raise ValueError(f"{label} can't be in the future.")
        return aware
    elif value > now.date():
        raise ValueError(f"{label} can't be in the future.")
    return value




def iso(value):
    if value is None:
        return None
    if isinstance(value, datetime) and value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.isoformat()


# ---------- Auth ----------

class RegisterIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=200)
    email: Email
    password: str = Field(min_length=8, max_length=128)
    date_of_birth: date
    gender: Literal["Male", "Female"]
    phone: str | None = None

    _phone = field_validator("phone")(_phone)

    @field_validator("date_of_birth")
    @classmethod
    def _dob(cls, v: date):
        _not_future(v, "Date of birth")
        if v.year < 1900:
            raise ValueError("Enter a valid date of birth.")
        return v


class LoginIn(BaseModel):
    email: Email
    password: str = Field(min_length=1, max_length=128)


class ForgotPasswordIn(BaseModel):
    email: Email


class ResetPasswordIn(BaseModel):
    token: str = Field(min_length=10)
    new_password: str = Field(min_length=8, max_length=128)


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


def user_out(user: m.User) -> dict:
    out = {
        "id": user.id, "email": user.email, "role": user.role, "full_name": user.full_name,
        "is_active": user.is_active, "is_demo": user.is_demo,
    }
    if user.patient:
        out["patient_id"] = user.patient.id
        out["patient_code"] = user.patient.patient_code
    if user.doctor:
        out["doctor_id"] = user.doctor.id
        out["doctor_code"] = user.doctor.doctor_code
    return out


# ---------- Patient profile ----------

class PatientProfileIn(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=200)
    date_of_birth: date | None = None
    gender: Literal["Male", "Female"] | None = None
    phone: str | None = None
    emergency_name: str | None = Field(default=None, max_length=200)
    emergency_relationship: str | None = Field(default=None, max_length=100)
    emergency_phone: str | None = None

    _phones = field_validator("phone", "emergency_phone")(_phone)

    @field_validator("date_of_birth")
    @classmethod
    def _dob(cls, v):
        return _not_future(v, "Date of birth")


def age_from(dob: date | None) -> int | None:
    if dob is None:
        return None
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def patient_out(p: m.Patient, body: dict | None = None) -> dict:
    return {
        "id": p.id, "patient_code": p.patient_code, "full_name": p.user.full_name, "email": p.user.email,
        "date_of_birth": iso(p.date_of_birth), "age": age_from(p.date_of_birth), "gender": p.gender,
        "phone": p.phone, "has_photo": bool(p.photo_ref),
        "emergency_contact": {"name": p.emergency_name, "relationship": p.emergency_relationship, "phone": p.emergency_phone},
        "is_active": p.user.is_active, "is_demo": p.user.is_demo, "created_at": iso(p.created_at),
        "body": body,
    }


def doctor_out(d: m.Doctor) -> dict:
    return {
        "id": d.id, "doctor_code": d.doctor_code, "full_name": d.user.full_name, "email": d.user.email,
        "specialization": d.specialization, "license_number": d.license_number, "phone": d.phone,
        "is_active": d.user.is_active, "is_demo": d.user.is_demo, "created_at": iso(d.created_at),
    }


# ---------- Access ----------

class AccessRequestIn(BaseModel):
    patient_name: str = Field(min_length=2, max_length=200)
    patient_code: str
    message: str | None = Field(default=None, max_length=500)

    @field_validator("patient_code")
    @classmethod
    def _code(cls, v: str):
        v = v.strip().upper()
        if not PATIENT_CODE_RE.match(v):
            raise ValueError("Patient ID should look like SUS-P-8A42F1.")
        return v


def access_out(a: m.AccessRequest) -> dict:
    return {
        "id": a.id, "status": a.status, "message": a.message, "requested_at": iso(a.created_at),
        "responded_at": iso(a.responded_at), "revoked_at": iso(a.revoked_at),
        "doctor": {"id": a.doctor.id, "name": a.doctor.user.full_name, "doctor_code": a.doctor.doctor_code, "specialization": a.doctor.specialization},
        "patient": {"id": a.patient.id, "name": a.patient.user.full_name, "patient_code": a.patient.patient_code},
    }


# ---------- Reports ----------

def report_out(r: m.Report) -> dict:
    return {
        "id": r.id, "report_code": r.report_code, "patient_id": r.patient_id, "category": r.category,
        "categories": list(r.categories or [r.category]),
        "report_date": iso(r.report_date), "uploaded_at": iso(r.uploaded_at),
        "uploaded_by": {"role": r.uploaded_by_role, "user_id": r.uploader_user_id, "name": r.uploader_name},
        "original_filename": r.original_filename, "file_type": r.file_type, "file_size": r.file_size,
        "description": r.description,
    }


def summary_out(s: m.AISummary, stale: bool = False, based_on: list[str] | None = None) -> dict:
    return {
        "id": s.id, "kind": s.kind, "subject_id": s.subject_id, "content": s.content,
        "source_ids": s.source_ids, "based_on": based_on or [], "provider": s.provider, "model": s.model,
        "generated_at": iso(s.generated_at), "generated_by_role": s.generated_by_role, "is_stale": stale,
    }


class AllReportsSummaryIn(BaseModel):
    report_ids: list[str] | None = None


# ---------- Diabetes ----------

def assessment_out(a: m.DiabetesAssessment, interpretation: dict | None = None) -> dict:
    return {
        "id": a.id, "assessment_code": a.assessment_code, "patient_id": a.patient_id,
        "assessed_at": iso(a.assessed_at), "model_version": a.model_version, "model_name": a.model_name, "inputs": a.inputs,
        "prediction": a.prediction, "classification_probability": a.classification_probability,
        "interpretation": a.interpretation, "disclaimer": a.disclaimer,
        "lifestyle_snapshot": a.lifestyle_snapshot, "performed_by_role": a.performed_by_role,
        "ai_interpretation": interpretation,
    }


# ---------- Glucose / food / lifestyle ----------

class GlucoseIn(BaseModel):
    value: float = Field(gt=0)
    unit: Literal["mg/dL", "mmol/L"] = "mg/dL"
    reading_type: Literal["fasting", "post_meal", "random"]
    measured_at: datetime
    source: Literal["manual", "device", "imported"] = "manual"
    context: str | None = Field(default=None, max_length=500)

    @field_validator("measured_at")
    @classmethod
    def _past(cls, v):
        return _not_future(v, "Reading time")

    @model_validator(mode="after")
    def _check(self):
        low, high = (20, 600) if self.unit == "mg/dL" else (1.1, 33.3)
        if not low <= self.value <= high:
            raise ValueError(f"Glucose must be between {low} and {high} {self.unit}.")
        return self


def glucose_out(g: m.GlucoseReading) -> dict:
    return {
        "id": g.id, "value": g.value, "unit": g.unit, "reading_type": g.reading_type,
        "measured_at": iso(g.measured_at), "source": g.source, "context": g.context,
        "is_demo": g.is_demo, "created_at": iso(g.created_at),
    }


class FoodIn(BaseModel):
    food_name: str = Field(min_length=1, max_length=200)
    quantity: str = Field(min_length=1, max_length=100)
    meal_type: Literal["breakfast", "lunch", "dinner", "snack", "other"]
    eaten_at: datetime

    @field_validator("eaten_at")
    @classmethod
    def _past(cls, v):
        return _not_future(v, "Meal time")

    @field_validator("food_name", "quantity")
    @classmethod
    def _strip(cls, v: str):
        v = v.strip()
        if not v:
            raise ValueError("This field is required.")
        return v


def food_out(f: m.FoodEntry) -> dict:
    return {
        "id": f.id, "food_name": f.food_name, "quantity": f.quantity, "meal_type": f.meal_type,
        "eaten_at": iso(f.eaten_at), "previous_id": f.previous_id, "created_at": iso(f.created_at),
        "is_edited": f.previous_id is not None,
    }


class LifestyleIn(BaseModel):
    metric_type: Literal["steps", "heart_rate", "sleep", "activity", "blood_pressure", "spo2", "calories"]
    value: float
    value2: float | None = None
    recorded_at: datetime

    @field_validator("recorded_at")
    @classmethod
    def _past(cls, v):
        return _not_future(v, "Time")


def metric_out(x: m.LifestyleMetric) -> dict:
    return {
        "id": x.id, "metric_type": x.metric_type, "value": x.value, "value2": x.value2, "unit": x.unit,
        "recorded_at": iso(x.recorded_at), "started_at": iso(x.started_at), "local_date": iso(x.local_date),
        "synced_at": iso(x.synced_at or x.created_at), "source": x.source, "is_demo": x.is_demo,
    }


class WearableConnectIn(BaseModel):
    provider: str
    granted_metrics: list[str] | None = None
    platform: Literal["android", "ios"] | None = None


class WearableSyncIn(BaseModel):
    samples: list[dict] | None = Field(default=None, max_length=5000)
    granted_metrics: list[str] | None = None


def wearable_out(w: m.WearableConnection) -> dict:
    return {
        "id": w.id, "provider": w.provider, "device_name": w.device_name, "status": w.status,
        "last_synced_at": iso(w.last_synced_at), "last_error": w.last_error,
        "supported_metrics": w.supported_metrics, "granted_metrics": w.granted_metrics, "platform": w.platform,
        "is_demo": w.is_demo, "connected_at": iso(w.created_at), "disconnected_at": iso(w.disconnected_at),
    }


# ---------- Side effects / appointments ----------

class SideEffectIn(BaseModel):
    description: str = Field(min_length=3, max_length=2000)
    severity: Literal["mild", "moderate", "severe", "emergency"]
    related_medication: str | None = Field(default=None, max_length=200)
    occurred_at: datetime
    notes: str | None = Field(default=None, max_length=2000)

    @field_validator("occurred_at")
    @classmethod
    def _past(cls, v):
        return _not_future(v, "Date")


class SideEffectResponseIn(BaseModel):
    response_type: Literal["no_immediate_action", "monitor", "contact_doctor", "appointment_recommended", "urgent_medical_attention"]
    message: str | None = Field(default=None, max_length=2000)
    appointment_reason: str | None = Field(default=None, max_length=1000)
    appointment_for: datetime | None = None


class SideEffectStatusIn(BaseModel):
    status: Literal["under_review", "resolved"]
    message: str | None = Field(default=None, max_length=1000)


def side_effect_out(s: m.SideEffect, events: list[m.SideEffectEvent] | None = None) -> dict:
    out = {
        "id": s.id, "side_effect_code": s.side_effect_code, "patient_id": s.patient_id,
        "description": s.description, "severity": s.severity, "related_medication": s.related_medication,
        "occurred_at": iso(s.occurred_at), "notes": s.notes, "status": s.status,
        "priority_flag": s.priority_flag, "created_at": iso(s.created_at),
    }
    if events is not None:
        out["history"] = [
            {
                "id": e.id, "status": e.status, "response_type": e.response_type, "message": e.message,
                "actor_name": e.actor_name, "actor_role": e.actor_role, "created_at": iso(e.created_at),
            }
            for e in events
        ]
    return out


class AppointmentIn(BaseModel):
    reason: str = Field(min_length=3, max_length=1000)
    recommended_for: datetime | None = None
    side_effect_id: str | None = None


def appointment_out(a: m.AppointmentRecommendation) -> dict:
    return {
        "id": a.id, "patient_id": a.patient_id, "doctor_id": a.doctor_id, "doctor_name": a.doctor_name,
        "side_effect_id": a.side_effect_id, "reason": a.reason, "recommended_for": iso(a.recommended_for),
        "created_at": iso(a.created_at),
    }


# ---------- Visits / prescriptions ----------

class VisitIn(BaseModel):
    visit_date: date
    reason: str = Field(min_length=2, max_length=1000)
    clinical_notes: str | None = Field(default=None, max_length=5000)
    assessment: str | None = Field(default=None, max_length=5000)
    doctor_reasoning: str | None = Field(default=None, max_length=5000)
    treatment_decision: str | None = Field(default=None, max_length=5000)
    follow_up_date: date | None = None
    instructions: str | None = Field(default=None, max_length=5000)

    @field_validator("visit_date")
    @classmethod
    def _past(cls, v):
        return _not_future(v, "Visit date")

    @model_validator(mode="after")
    def _check(self):
        if self.follow_up_date and self.follow_up_date < self.visit_date:
            raise ValueError("Follow-up date must be after the visit date.")
        return self


def visit_out(v: m.Visit) -> dict:
    return {
        "id": v.id, "visit_code": v.visit_code, "patient_id": v.patient_id, "doctor_id": v.doctor_id,
        "doctor_name": v.doctor_name, "visit_date": iso(v.visit_date), "reason": v.reason,
        "clinical_notes": v.clinical_notes, "assessment": v.assessment, "doctor_reasoning": v.doctor_reasoning,
        "treatment_decision": v.treatment_decision, "follow_up_date": iso(v.follow_up_date),
        "instructions": v.instructions, "created_at": iso(v.created_at),
    }


class MedicineIn(BaseModel):
    medicine: str = Field(min_length=1, max_length=200)
    dosage: str = Field(min_length=1, max_length=100)
    frequency: str = Field(min_length=1, max_length=100)
    duration: str = Field(min_length=1, max_length=100)
    instructions: str | None = Field(default=None, max_length=500)


class PrescriptionIn(BaseModel):
    prescribed_on: date
    medicines: list[MedicineIn] = Field(min_length=1, max_length=30)
    instructions: str | None = Field(default=None, max_length=2000)
    notes: str | None = Field(default=None, max_length=2000)
    follow_up_date: date | None = None

    @field_validator("prescribed_on")
    @classmethod
    def _past(cls, v):
        return _not_future(v, "Prescription date")

    @model_validator(mode="after")
    def _check(self):
        if self.follow_up_date and self.follow_up_date < self.prescribed_on:
            raise ValueError("Follow-up date must be after the prescription date.")
        return self


def prescription_out(p: m.Prescription) -> dict:
    return {
        "id": p.id, "prescription_code": p.prescription_code, "patient_id": p.patient_id,
        "doctor_id": p.doctor_id, "doctor_name": p.doctor_name, "prescribed_on": iso(p.prescribed_on),
        "instructions": p.instructions, "notes": p.notes, "follow_up_date": iso(p.follow_up_date),
        "created_at": iso(p.created_at),
        "medicines": [
            {"medicine": i.medicine, "dosage": i.dosage, "frequency": i.frequency, "duration": i.duration, "instructions": i.instructions}
            for i in p.items
        ],
    }


# ---------- Notifications ----------

def notification_out(n: m.Notification) -> dict:
    return {
        "id": n.id, "type": n.type, "title": n.title, "body": n.body, "entity_type": n.entity_type,
        "entity_id": n.entity_id, "patient_id": n.patient_id, "is_read": n.is_read,
        "created_at": iso(n.created_at), "read_at": iso(n.read_at),
    }


class PreferencesIn(BaseModel):
    food_reminders: bool | None = None
    lifestyle_reminders: bool | None = None
    follow_up_reminders: bool | None = None
    doctor_notifications: bool | None = None


# ---------- Admin ----------

class DoctorCreateIn(BaseModel):
    full_name: str = Field(min_length=2, max_length=200)
    email: Email
    temporary_password: str = Field(min_length=8, max_length=128)
    specialization: str | None = Field(default=None, max_length=120)
    license_number: str = Field(min_length=3, max_length=80)
    phone: str | None = None

    _phone = field_validator("phone")(_phone)
    _license = field_validator("license_number")(lambda v: _required_text(v, "License / registration number"))


class DoctorUpdateIn(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=200)
    specialization: str | None = Field(default=None, max_length=120)
    license_number: str | None = Field(default=None, min_length=3, max_length=80)
    phone: str | None = None
    is_active: bool | None = None

    _phone = field_validator("phone")(_phone)


class AccountStatusIn(BaseModel):
    is_active: bool


class PatientAdminUpdateIn(BaseModel):
    """Administrative details an admin may correct. Date of birth and gender are excluded:
    they are the patient's own inputs to the diabetes model."""

    full_name: str | None = Field(default=None, min_length=2, max_length=200)
    phone: str | None = None
    emergency_name: str | None = Field(default=None, max_length=200)
    emergency_relationship: str | None = Field(default=None, max_length=100)
    emergency_phone: str | None = None

    _phones = field_validator("phone", "emergency_phone")(_phone)


class SettingsIn(BaseModel):
    values: dict[str, str]


def audit_out(a: m.AuditLog) -> dict:
    return {
        "id": a.id, "created_at": iso(a.created_at), "actor_name": a.actor_name, "actor_role": a.actor_role,
        "action": a.action, "entity_type": a.entity_type, "entity_id": a.entity_id,
        "entity_label": a.entity_label, "details": a.details,
    }

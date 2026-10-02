"""Authentication and authorization dependencies.

Every patient-scoped endpoint goes through `authorize_patient`, so hiding a button in the
app is never the only protection.
"""

from dataclasses import dataclass
from datetime import datetime, timezone

import jwt
from fastapi import Depends, Header
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import errors
from .db import get_db
from .models import AccessRequest, AuthSession, Doctor, Patient, User
from .security import decode_access_token


@dataclass
class CurrentUser:
    user: User
    session_id: str

    @property
    def id(self) -> str:
        return self.user.id

    @property
    def role(self) -> str:
        return self.user.role

    @property
    def name(self) -> str:
        return self.user.full_name


def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> CurrentUser:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise errors.unauthorized()
    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = decode_access_token(token)
    except jwt.ExpiredSignatureError:
        raise errors.unauthorized("Your session has expired. Please sign in again.")
    except jwt.PyJWTError:
        raise errors.unauthorized()

    session = db.get(AuthSession, payload.get("jti"))
    now = datetime.now(timezone.utc)
    if session is None or session.revoked_at is not None or _aware(session.expires_at) < now:
        raise errors.unauthorized("Your session has ended. Please sign in again.")
    user = db.get(User, payload.get("sub"))
    if user is None or not user.is_active:
        raise errors.unauthorized("This account is not active.")
    return CurrentUser(user=user, session_id=session.id)


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def require_roles(*roles: str):
    def dependency(current: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if current.role not in roles:
            raise errors.forbidden()
        return current

    return dependency


require_patient = require_roles("patient")
require_doctor = require_roles("doctor")
require_admin = require_roles("admin")
require_clinical = require_roles("patient", "doctor")
# Read-only endpoints for patient records. Writes stay on require_clinical / require_patient /
# require_doctor, so an admin can inspect a record but never author or change one.
require_record_reader = require_roles("patient", "doctor", "admin")


def current_patient(db: Session, current: CurrentUser) -> Patient:
    patient = db.scalar(select(Patient).where(Patient.user_id == current.id))
    if patient is None:
        raise errors.forbidden()
    return patient


def current_doctor(db: Session, current: CurrentUser) -> Doctor:
    doctor = db.scalar(select(Doctor).where(Doctor.user_id == current.id))
    if doctor is None:
        raise errors.forbidden()
    return doctor


def doctor_has_access(db: Session, doctor_id: str, patient_id: str) -> bool:
    return (
        db.scalar(
            select(AccessRequest.id).where(
                AccessRequest.doctor_id == doctor_id,
                AccessRequest.patient_id == patient_id,
                AccessRequest.status == "approved",
            )
        )
        is not None
    )


def authorize_patient(db: Session, current: CurrentUser, patient_id: str) -> Patient:
    """Returns the patient if the caller may access their clinical records.

    Patient: only themselves. Doctor: only with an approved access request.
    Admin: any patient, read-only. Every write endpoint's role gate excludes admin, so an
    admin never reaches this function on a write and records keep their original authors.
    """
    patient = db.get(Patient, patient_id)
    if patient is None:
        # Same response as forbidden for doctors, so ids can't be probed.
        raise errors.forbidden() if current.role == "doctor" else errors.not_found("Patient")
    if current.role == "admin":
        return patient
    if current.role == "patient":
        if patient.user_id != current.id:
            raise errors.forbidden()
        return patient
    if current.role == "doctor":
        doctor = current_doctor(db, current)
        if not doctor_has_access(db, doctor.id, patient.id):
            raise errors.forbidden("You don't have access to this patient's records. Ask the patient to approve your access request.")
        return patient
    raise errors.forbidden()

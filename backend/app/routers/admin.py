"""System management: accounts, access and settings. Admin's read-only views of a doctor's or
patient's complete record live in admin_profiles.py."""

from datetime import date, datetime, timedelta, timezone

from fastapi import BackgroundTasks, APIRouter, Depends, File, Form, Query, UploadFile
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, require_admin
from ..models import AccessRequest, AuditLog, AuthSession, Doctor, Patient, SystemSetting, User, utcnow
from ..schemas import AccountStatusIn, DoctorCreateIn, DoctorUpdateIn, PatientAdminUpdateIn, SettingsIn, age_from, audit_out, doctor_out, iso, patient_out, report_out
from ..services.health_data.report_extraction import extract_in_background, needs_ai
from ..services.admin_views import latest_assessment, patient_last_activity
from ..security import PASSWORD_RULES, hash_password, password_is_strong, random_code
from ..services.records import audit
from .reports import store_report

router = APIRouter(prefix="/admin", tags=["admin"])

EDITABLE_SETTINGS = {
    "support_email": "",
    "max_upload_mb_display": "20",
    "maintenance_notice": "",
}


@router.get("/dashboard")
def dashboard(current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    thirty_days = datetime.now(timezone.utc) - timedelta(days=30)
    count = lambda q: db.scalar(select(func.count()).select_from(q.subquery()))  # noqa: E731
    return {
        "metrics": {
            "total_doctors": count(select(Doctor.id)),
            "active_doctors": count(select(Doctor.id).join(User).where(User.is_active.is_(True))),
            "total_patients": count(select(Patient.id)),
            "active_patients": count(select(Patient.id).join(User).where(User.is_active.is_(True), or_(User.last_login_at >= thirty_days, User.created_at >= thirty_days))),
            "pending_requests": count(select(AccessRequest.id).where(AccessRequest.status == "pending")),
        },
        # Sign-ins stay in the full audit log; the dashboard shows account and access changes.
        "recent_activity": [audit_out(a) for a in db.scalars(select(AuditLog).where(AuditLog.action.not_in(["login", "patient_record_viewed"])).order_by(AuditLog.created_at.desc()).limit(10))],
    }


# ---------- Doctors ----------

@router.get("/doctors")
def list_doctors(q: str | None = Query(None, max_length=100), status: str = Query("all", pattern="^(all|active|inactive)$"),
                 current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    query = select(Doctor).join(User)
    if q:
        like = f"%{q.lower()}%"
        query = query.where(or_(func.lower(User.full_name).like(like), func.lower(User.email).like(like), func.lower(Doctor.doctor_code).like(like)))
    if status != "all":
        query = query.where(User.is_active.is_(status == "active"))
    return {"items": [_doctor_row(db, d) for d in db.scalars(query.order_by(User.full_name))]}


def _doctor_row(db: Session, d: Doctor) -> dict:
    from .admin_profiles import doctor_last_activity

    return {
        **doctor_out(d),
        "active_patients": db.scalar(select(func.count(AccessRequest.id)).where(AccessRequest.doctor_id == d.id, AccessRequest.status == "approved")),
        "last_login_at": iso(d.user.last_login_at),
        "last_activity_at": iso(doctor_last_activity(db, d)),
    }


@router.post("/doctors", status_code=201)
def create_doctor(body: DoctorCreateIn, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    if not password_is_strong(body.temporary_password):
        raise errors.unprocessable(f"Temporary password must be {PASSWORD_RULES}.", {"field": "temporary_password"})
    email = body.email.lower()
    if db.scalar(select(User.id).where(User.email == email)):
        raise errors.conflict("An account with this email already exists.")
    user = User(email=email, password_hash=hash_password(body.temporary_password), role="doctor", full_name=body.full_name.strip())
    db.add(user)
    db.flush()
    code = random_code("SUS-D")
    while db.scalar(select(Doctor.id).where(Doctor.doctor_code == code)):
        code = random_code("SUS-D")
    doctor = Doctor(user_id=user.id, doctor_code=code, specialization=body.specialization, license_number=body.license_number, phone=body.phone)
    db.add(doctor)
    db.flush()
    db.refresh(doctor)
    audit(db, current, "doctor_created", "doctor", doctor.id, doctor.doctor_code)
    db.commit()
    return doctor_out(doctor)


@router.patch("/doctors/{doctor_id}")
def update_doctor(doctor_id: str, body: DoctorUpdateIn, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    doctor = db.get(Doctor, doctor_id)
    if doctor is None:
        raise errors.not_found("Doctor")
    data = body.model_dump(exclude_unset=True)
    if "full_name" in data and data["full_name"]:
        doctor.user.full_name = data.pop("full_name").strip()
    if "is_active" in data:
        active = data.pop("is_active")
        if doctor.user.is_active != active:
            doctor.user.is_active = active
            if not active:
                _end_sessions(db, doctor.user_id)
            audit(db, current, "doctor_activated" if active else "doctor_deactivated", "doctor", doctor.id, doctor.doctor_code)
    for key, value in data.items():
        setattr(doctor, key, value)
    audit(db, current, "doctor_updated", "doctor", doctor.id, doctor.doctor_code, {"fields": sorted(body.model_fields_set)})
    db.commit()
    return doctor_out(doctor)


def _end_sessions(db: Session, user_id: str) -> None:
    for session in db.scalars(select(AuthSession).where(AuthSession.user_id == user_id, AuthSession.revoked_at.is_(None))):
        session.revoked_at = utcnow()


# ---------- Patients ----------

@router.get("/patients")
def list_patients(q: str | None = Query(None, max_length=100), status: str = Query("all", pattern="^(all|active|inactive)$"),
                  limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
                  current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    query = select(Patient).join(User)
    if q:
        like = f"%{q.lower()}%"
        query = query.where(or_(func.lower(User.full_name).like(like), func.lower(User.email).like(like), func.lower(Patient.patient_code).like(like)))
    if status != "all":
        query = query.where(User.is_active.is_(status == "active"))
    total = db.scalar(select(func.count()).select_from(query.subquery()))
    rows = db.scalars(query.order_by(User.created_at.desc()).limit(limit).offset(offset))
    return {"total": total, "items": [_patient_row(db, p) for p in rows]}


def _patient_row(db: Session, p: Patient) -> dict:
    latest = latest_assessment(db, p.id)
    return {
        "id": p.id, "patient_code": p.patient_code, "full_name": p.user.full_name, "email": p.user.email,
        "age": age_from(p.date_of_birth), "gender": p.gender,
        "is_active": p.user.is_active, "is_demo": p.user.is_demo, "created_at": iso(p.created_at),
        "last_login_at": iso(p.user.last_login_at), "last_activity_at": iso(patient_last_activity(db, p)),
        "latest_prediction": latest.prediction_label if latest else None,
        "latest_risk_percent": latest.risk_percent if latest else None,
        "latest_risk_category": latest.risk_category if latest else None,
        "approved_doctors": db.scalar(select(func.count(AccessRequest.id)).where(AccessRequest.patient_id == p.id, AccessRequest.status == "approved")),
    }


@router.patch("/patients/{patient_id}")
def update_patient(patient_id: str, body: PatientAdminUpdateIn, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Corrects administrative details (name, contact, emergency contact). Never touches
    medical records; the change and its author are audited."""
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise errors.not_found("Patient")
    data = body.model_dump(exclude_unset=True)
    if data.get("full_name"):
        patient.user.full_name = data.pop("full_name").strip()
    data.pop("full_name", None)
    for key, value in data.items():
        setattr(patient, key, value.strip() if isinstance(value, str) and value.strip() else None)
    audit(db, current, "patient_updated_by_admin", "patient", patient.id, patient.patient_code, {"fields": sorted(body.model_fields_set)})
    db.commit()
    return patient_out(patient)


@router.post("/patients/{patient_id}/status")
def set_patient_status(patient_id: str, body: AccountStatusIn, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """Deactivation blocks sign-in. It never deletes medical records."""
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise errors.not_found("Patient")
    patient.user.is_active = body.is_active
    if not body.is_active:
        _end_sessions(db, patient.user_id)
    audit(db, current, "patient_activated" if body.is_active else "patient_deactivated", "patient", patient.id, patient.patient_code)
    db.commit()
    return {"id": patient.id, "is_active": patient.user.is_active}


@router.post("/patients/{patient_id}/reports", status_code=201)
async def admin_upload_report(
    patient_id: str,
    category: str = Form(...),
    report_date: date = Form(...),
    description: str | None = Form(None),
    file: UploadFile = File(...),
    background: BackgroundTasks = None,
    current: CurrentUser = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin may add a report on a patient's behalf (write-only; admin cannot read it back)."""
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise errors.not_found("Patient")
    report = await store_report(db, current, patient, category, report_date, description, file)
    db.commit()
    if needs_ai(report) and background is not None:
        background.add_task(extract_in_background, report.id)
    out = report_out(report)
    return {k: out[k] for k in ("id", "report_code", "category", "report_date", "uploaded_at", "uploaded_by")}


# ---------- Audit / settings ----------

@router.get("/audit-logs")
def audit_logs(
    q: str | None = Query(None, max_length=100), action: str | None = None,
    start: date | None = None, end: date | None = None,
    limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db),
):
    query = select(AuditLog)
    if action:
        query = query.where(AuditLog.action == action)
    if q:
        like = f"%{q.lower()}%"
        query = query.where(or_(func.lower(AuditLog.actor_name).like(like), func.lower(AuditLog.entity_label).like(like), func.lower(AuditLog.action).like(like)))
    if start:
        query = query.where(AuditLog.created_at >= datetime(start.year, start.month, start.day, tzinfo=timezone.utc))
    if end:
        query = query.where(AuditLog.created_at < datetime(end.year, end.month, end.day, tzinfo=timezone.utc) + timedelta(days=1))
    total = db.scalar(select(func.count()).select_from(query.subquery()))
    rows = db.scalars(query.order_by(AuditLog.created_at.desc()).limit(limit).offset(offset))
    return {"items": [audit_out(a) for a in rows], "total": total}


@router.get("/settings")
def get_system_settings(current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    stored = {s.key: s.value for s in db.scalars(select(SystemSetting))}
    from ..config import get_settings

    settings = get_settings()
    return {
        "values": {k: stored.get(k, v) for k, v in EDITABLE_SETTINGS.items()},
        "status": {
            "environment": settings.susthiti_env,
            "ai_configured": settings.ai_configured,
            "ai_model": settings.gemini_model,
            "ml_service_url_configured": bool(settings.ml_service_url),
            "demo_wearable_enabled": settings.enable_demo_wearable,
        },
    }


@router.put("/settings")
def update_system_settings(body: SettingsIn, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    unknown = set(body.values) - set(EDITABLE_SETTINGS)
    if unknown:
        raise errors.unprocessable("Unknown setting.", {"unknown": sorted(unknown)})
    for key, value in body.values.items():
        row = db.get(SystemSetting, key)
        if row is None:
            db.add(SystemSetting(key=key, value=value))
        else:
            row.value, row.updated_at = value, utcnow()
    audit(db, current, "settings_updated", "settings", None, None, {"keys": sorted(body.values)})
    db.commit()
    return get_system_settings(current, db)

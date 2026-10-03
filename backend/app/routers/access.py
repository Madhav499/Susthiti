"""Doctor-patient access requests and the doctor's workspace."""

from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, current_doctor, current_patient, get_current_user, require_doctor, require_patient
from ..models import AccessRequest, AppointmentRecommendation, AuditLog, FollowUp, Patient, Prescription, Report, SideEffect, Surgery, User, Visit, utcnow
from ..schemas import AccessRequestIn, access_out, iso
from ..services.records import audit, notify

router = APIRouter(tags=["access"])


@router.post("/access-requests", status_code=201)
def request_access(body: AccessRequestIn, current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    """Doctor must supply BOTH the patient's name and Patient ID. The response never reveals
    records; access starts only after the patient approves."""
    doctor = current_doctor(db, current)
    patient = db.scalar(select(Patient).join(User).where(Patient.patient_code == body.patient_code, User.is_active.is_(True)))
    if patient is None or patient.user.full_name.strip().lower() != body.patient_name.strip().lower():
        raise errors.not_found("No patient matches that name and Patient ID. Patient")
    existing = db.scalar(select(AccessRequest).where(
        AccessRequest.doctor_id == doctor.id, AccessRequest.patient_id == patient.id,
        AccessRequest.status.in_(["pending", "approved"]),
    ))
    if existing:
        raise errors.conflict("You already have a pending or approved request for this patient.")
    req = AccessRequest(doctor_id=doctor.id, patient_id=patient.id, status="pending", message=body.message)
    db.add(req)
    db.flush()
    notify(db, patient.user_id, "access_request", "Doctor access request",
           f"Dr. {current.name} has requested access to your health records.", "access_request", req.id, patient.id)
    audit(db, current, "access_requested", "access_request", req.id, None, {"patient_code": patient.patient_code, "doctor_code": doctor.doctor_code})
    db.commit()
    db.refresh(req)
    return access_out(req)


@router.get("/access-requests")
def list_access_requests(status: str | None = None, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    query = select(AccessRequest)
    if current.role == "patient":
        query = query.where(AccessRequest.patient_id == current_patient(db, current).id)
    elif current.role == "doctor":
        query = query.where(AccessRequest.doctor_id == current_doctor(db, current).id)
    # admin sees all (system-level access management)
    if status:
        query = query.where(AccessRequest.status == status)
    rows = db.scalars(query.order_by(AccessRequest.created_at.desc()).limit(200))
    return {"items": [access_out(a) for a in rows]}


def _patient_request(db: Session, current: CurrentUser, request_id: str) -> AccessRequest:
    req = db.get(AccessRequest, request_id)
    if req is None or req.patient_id != current_patient(db, current).id:
        raise errors.not_found("Access request")
    return req


@router.post("/access-requests/{request_id}/approve")
def approve(request_id: str, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    req = _patient_request(db, current, request_id)
    if req.status != "pending":
        raise errors.conflict("This request has already been answered.")
    req.status, req.responded_at = "approved", utcnow()
    notify(db, req.doctor.user_id, "access_approved", "Access approved",
           f"{req.patient.user.full_name} ({req.patient.patient_code}) approved your access request.", "patient", req.patient_id, req.patient_id)
    audit(db, current, "access_approved", "access_request", req.id, None, {"patient_code": req.patient.patient_code, "doctor_code": req.doctor.doctor_code})
    db.commit()
    return access_out(req)


@router.post("/access-requests/{request_id}/reject")
def reject(request_id: str, current: CurrentUser = Depends(require_patient), db: Session = Depends(get_db)):
    req = _patient_request(db, current, request_id)
    if req.status != "pending":
        raise errors.conflict("This request has already been answered.")
    req.status, req.responded_at = "rejected", utcnow()
    notify(db, req.doctor.user_id, "access_rejected", "Access request declined",
           f"{req.patient.patient_code} declined your access request.", "access_request", req.id)
    audit(db, current, "access_rejected", "access_request", req.id, None, {"patient_code": req.patient.patient_code, "doctor_code": req.doctor.doctor_code})
    db.commit()
    return access_out(req)


@router.post("/access-requests/{request_id}/revoke")
def revoke(request_id: str, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    """Patient (own requests) or Admin can revoke. Records the doctor created stay in the
    patient's history; the doctor simply loses access."""
    req = db.get(AccessRequest, request_id)
    if req is None:
        raise errors.not_found("Access request")
    if current.role == "patient":
        if req.patient_id != current_patient(db, current).id:
            raise errors.not_found("Access request")
    elif current.role != "admin":
        raise errors.forbidden()
    if req.status != "approved" and req.status != "pending":
        raise errors.conflict("Only pending or approved access can be revoked.")
    req.status, req.revoked_at, req.revoked_by_user_id = "revoked", utcnow(), current.id
    notify(db, req.doctor.user_id, "access_revoked", "Access revoked",
           f"Your access to {req.patient.patient_code} has been revoked.", "access_request", req.id)
    audit(db, current, "access_revoked", "access_request", req.id, None, {"patient_code": req.patient.patient_code, "doctor_code": req.doctor.doctor_code})
    db.commit()
    return access_out(req)


# ---------- Doctor workspace ----------

def _approved_patient_ids(db: Session, doctor_id: str) -> list[str]:
    return list(db.scalars(select(AccessRequest.patient_id).where(AccessRequest.doctor_id == doctor_id, AccessRequest.status == "approved")))


@router.get("/doctor/patients")
def doctor_patients(
    q: str | None = Query(None, max_length=100),
    filter: str = Query("all", pattern="^(all|recent_activity|follow_up|side_effects)$"),
    current: CurrentUser = Depends(require_doctor),
    db: Session = Depends(get_db),
):
    doctor = current_doctor(db, current)
    ids = _approved_patient_ids(db, doctor.id)
    query = select(Patient).join(User).where(Patient.id.in_(ids))
    if q:
        like = f"%{q.strip().lower()}%"
        query = query.where(or_(func.lower(User.full_name).like(like), func.lower(Patient.patient_code).like(like)))
    patients = list(db.scalars(query.order_by(User.full_name)))
    today = datetime.now(timezone.utc).date()
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    items = []
    for p in patients:
        open_effects = db.scalar(select(func.count(SideEffect.id)).where(SideEffect.patient_id == p.id, SideEffect.status.in_(["new", "under_review"])))
        follow_up = _next_follow_up(db, p.id, today)
        last_report = db.scalar(select(func.max(Report.uploaded_at)).where(Report.patient_id == p.id))
        last_effect = db.scalar(select(func.max(SideEffect.created_at)).where(SideEffect.patient_id == p.id))
        activity = max([d for d in (last_report, last_effect) if d is not None], default=None)
        item = {
            "id": p.id, "name": p.user.full_name, "patient_code": p.patient_code, "gender": p.gender,
            "age": (today.year - p.date_of_birth.year - ((today.month, today.day) < (p.date_of_birth.month, p.date_of_birth.day))) if p.date_of_birth else None,
            "open_side_effects": open_effects, "next_follow_up": iso(follow_up), "last_activity_at": iso(activity),
        }
        recent = activity is not None and (activity if activity.tzinfo else activity.replace(tzinfo=timezone.utc)) >= week_ago
        if filter == "side_effects" and not open_effects:
            continue
        if filter == "follow_up" and not (follow_up and follow_up <= today + timedelta(days=7)):
            continue
        if filter == "recent_activity" and not recent:
            continue
        items.append(item)
    return {"items": items}


def _next_follow_up(db: Session, patient_id: str, today: date) -> date | None:
    dates = [
        db.scalar(select(func.min(Visit.follow_up_date)).where(Visit.patient_id == patient_id, Visit.follow_up_date >= today)),
        db.scalar(select(func.min(Prescription.follow_up_date)).where(Prescription.patient_id == patient_id, Prescription.follow_up_date >= today)),
        db.scalar(select(func.min(FollowUp.due_date)).where(FollowUp.patient_id == patient_id, FollowUp.status == "scheduled", FollowUp.due_date >= today)),
    ]
    dates = [d for d in dates if d]
    return min(dates) if dates else None


@router.get("/doctor/dashboard")
def doctor_dashboard(current: CurrentUser = Depends(require_doctor), db: Session = Depends(get_db)):
    doctor = current_doctor(db, current)
    ids = _approved_patient_ids(db, doctor.id)
    today = datetime.now(timezone.utc).date()
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    pending = db.scalar(select(func.count(AccessRequest.id)).where(AccessRequest.doctor_id == doctor.id, AccessRequest.status == "pending"))
    now = datetime.now(timezone.utc)
    # Scoped to `ids` (currently-approved patients): this is the doctor's own actionable view,
    # unlike admin's historical-workload view of a doctor, so a revoked access must disappear
    # from it immediately, same as everywhere else on this dashboard.
    upcoming_appointments = db.scalar(select(func.count(AppointmentRecommendation.id)).where(
        AppointmentRecommendation.doctor_id == doctor.id, AppointmentRecommendation.patient_id.in_(ids), AppointmentRecommendation.recommended_for >= now,
        AppointmentRecommendation.recommended_for < now + timedelta(days=7),
    ))
    upcoming_surgeries = db.scalar(select(func.count(Surgery.id)).where(
        Surgery.doctor_id == doctor.id, Surgery.patient_id.in_(ids), Surgery.status == "scheduled", Surgery.scheduled_at >= now, Surgery.scheduled_at < now + timedelta(days=7),
    ))
    open_effects = list(db.scalars(select(SideEffect).where(SideEffect.patient_id.in_(ids), SideEffect.status.in_(["new", "under_review"])).order_by(SideEffect.created_at.desc())))
    recent_reports = list(db.scalars(select(Report).where(Report.patient_id.in_(ids), Report.uploaded_at >= week_ago).order_by(Report.uploaded_at.desc()).limit(10)))
    follow_ups = []
    for pid in ids:
        due = _next_follow_up(db, pid, today)
        if due and due <= today + timedelta(days=7):
            follow_ups.append((pid, due))

    patients = {p.id: p for p in db.scalars(select(Patient).where(Patient.id.in_(ids)))}
    attention: dict[str, dict] = {}

    def add(pid: str, reason: str, at, entity_type: str, entity_id: str):
        entry = attention.setdefault(pid, {"patient_id": pid, "name": patients[pid].user.full_name, "patient_code": patients[pid].patient_code, "reasons": []})
        entry["reasons"].append({"reason": reason, "at": iso(at), "entity_type": entity_type, "entity_id": entity_id})

    for s in open_effects:
        add(s.patient_id, f"{s.severity.capitalize()} side effect reported", s.created_at, "side_effect", s.id)
    for pid, due in follow_ups:
        add(pid, f"Follow-up due {due:%d %b}", due, "patient", pid)
    for r in recent_reports:
        add(r.patient_id, "New report", r.uploaded_at, "report", r.id)

    activity = list(db.scalars(
        select(AuditLog).where(AuditLog.entity_type.in_(["report", "side_effect", "prescription", "visit", "access_request", "assessment"]),
                               or_(AuditLog.actor_user_id == current.id, AuditLog.details["patient_code"].as_string().in_([p.patient_code for p in patients.values()])))
        .order_by(AuditLog.created_at.desc()).limit(10)
    )) if patients else list(db.scalars(select(AuditLog).where(AuditLog.actor_user_id == current.id, AuditLog.entity_type.in_(["report", "side_effect", "prescription", "visit", "access_request", "assessment"])).order_by(AuditLog.created_at.desc()).limit(10)))

    # "My Day": every time-bound thing on this doctor's calendar today, earliest first. A
    # follow-up has no time of its own (see FollowUp's docstring) and is never given a fake one.
    day_start = datetime(today.year, today.month, today.day, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)

    def _patient_ref(pid: str) -> dict:
        p = patients.get(pid)
        return {"patient_id": pid, "patient_name": p.user.full_name if p else None, "patient_code": p.patient_code if p else None}

    # Scoped to `ids` (currently-approved patients only), same as needs_attention above: a
    # revoked access takes effect immediately, including for records made while it was active.
    today_items: list[dict] = []
    for a in db.scalars(select(AppointmentRecommendation).where(
        AppointmentRecommendation.doctor_id == doctor.id, AppointmentRecommendation.patient_id.in_(ids),
        AppointmentRecommendation.recommended_for >= day_start, AppointmentRecommendation.recommended_for < day_end,
    )):
        today_items.append({"type": "appointment", "id": a.id, "at": iso(a.recommended_for), "title": a.reason, **_patient_ref(a.patient_id)})
    for s in db.scalars(select(Surgery).where(
        Surgery.doctor_id == doctor.id, Surgery.patient_id.in_(ids), Surgery.status == "scheduled",
        Surgery.scheduled_at >= day_start, Surgery.scheduled_at < day_end,
    )):
        today_items.append({"type": "surgery", "id": s.id, "at": iso(s.scheduled_at), "title": s.name, **_patient_ref(s.patient_id)})
    for f in db.scalars(select(FollowUp).where(
        FollowUp.doctor_id == doctor.id, FollowUp.patient_id.in_(ids), FollowUp.status == "scheduled", FollowUp.due_date == today,
    )):
        today_items.append({"type": "follow_up", "id": f.id, "at": None, "title": f.purpose, **_patient_ref(f.patient_id)})
    today_items.sort(key=lambda i: (i["at"] is None, i["at"] or ""))

    return {
        "doctor": {"name": current.name, "doctor_code": doctor.doctor_code},
        "metrics": {
            "patients": len(ids), "pending_requests": pending, "open_side_effects": len(open_effects),
            "follow_ups_7d": len(follow_ups), "recent_reports_7d": len(recent_reports), "upcoming_appointments_7d": upcoming_appointments or 0,
            "upcoming_surgeries_7d": upcoming_surgeries or 0,
        },
        "needs_attention": list(attention.values())[:10],
        "today": today_items,
        "recent_activity": [
            {"actor_name": a.actor_name, "actor_role": a.actor_role, "action": a.action, "entity_label": a.entity_label, "patient_code": (a.details or {}).get("patient_code"), "created_at": iso(a.created_at)}
            for a in activity
        ],
    }

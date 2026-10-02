import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..config import get_settings
from ..db import get_db
from ..deps import CurrentUser, get_current_user
from ..models import AuthSession, Patient, PasswordResetToken, User, utcnow
from ..schemas import ChangePasswordIn, ForgotPasswordIn, LoginIn, RegisterIn, ResetPasswordIn, user_out
from ..security import (
    PASSWORD_RULES,
    create_access_token,
    hash_password,
    hash_token,
    new_reset_token,
    password_is_strong,
    random_code,
    session_expiry,
    verify_password,
)
from ..services.rate_limit import limit
from ..services.records import audit

router = APIRouter(prefix="/auth", tags=["auth"])
log = logging.getLogger("susthiti.auth")


def _issue_session(db: Session, user: User) -> dict:
    expires_at = session_expiry()
    session = AuthSession(user_id=user.id, expires_at=expires_at)
    db.add(session)
    db.flush()
    token = create_access_token(user.id, user.role, session.id, expires_at)
    return {"access_token": token, "token_type": "bearer", "expires_at": expires_at.isoformat(), "user": user_out(user)}


def _unique_patient_code(db: Session) -> str:
    while True:
        code = random_code("SUS-P")
        if not db.scalar(select(Patient.id).where(Patient.patient_code == code)):
            return code


@router.post("/register", status_code=201, dependencies=[Depends(limit("register", 20, 3600))])
def register(body: RegisterIn, db: Session = Depends(get_db)):
    """Public registration creates PATIENT accounts only. Doctors are created by Admin;
    admins only through the server-side CLI."""
    if not password_is_strong(body.password):
        raise errors.unprocessable(f"Password must be {PASSWORD_RULES}.", {"field": "password"})
    email = body.email.lower()
    if db.scalar(select(User.id).where(User.email == email)):
        raise errors.conflict("An account with this email already exists. Try signing in instead.")
    user = User(email=email, password_hash=hash_password(body.password), role="patient", full_name=body.full_name.strip())
    db.add(user)
    db.flush()
    patient = Patient(user_id=user.id, patient_code=_unique_patient_code(db), date_of_birth=body.date_of_birth, gender=body.gender, phone=body.phone)
    db.add(patient)
    db.flush()
    db.refresh(user)
    result = _issue_session(db, user)
    audit(db, CurrentUser(user, ""), "patient_registered", "patient", patient.id, patient.patient_code)
    db.commit()
    return result


@router.post("/login", dependencies=[Depends(limit("login", 20, 300))])
def login(body: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    if user is None or not verify_password(body.password, user.password_hash):
        raise errors.unauthorized("Email or password is incorrect.")
    if not user.is_active:
        raise errors.forbidden("This account has been deactivated. Please contact the administrator.")
    user.last_login_at = utcnow()
    result = _issue_session(db, user)
    audit(db, CurrentUser(user, ""), "login", "user", user.id, user.role)
    db.commit()
    return result


@router.get("/me")
def me(current: CurrentUser = Depends(get_current_user)):
    return user_out(current.user)


@router.post("/logout", status_code=204)
def logout(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    session = db.get(AuthSession, current.session_id)
    session.revoked_at = utcnow()
    audit(db, current, "logout", "user", current.id)
    db.commit()


@router.post("/forgot-password", dependencies=[Depends(limit("password-reset", 10, 3600))])
def forgot_password(body: ForgotPasswordIn, db: Session = Depends(get_db)):
    """Always answers the same way so account existence can't be probed."""
    settings = get_settings()
    response = {"message": "If an account exists for this email, password reset instructions have been sent."}
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    if user and user.is_active:
        token, token_hash = new_reset_token()
        db.add(PasswordResetToken(user_id=user.id, token_hash=token_hash, expires_at=datetime.now(timezone.utc) + timedelta(minutes=30)))
        audit(db, None, "password_reset_requested", "user", user.id)
        db.commit()
        # No email provider is configured in this build. In development only, the token is
        # returned so the recovery flow can be completed. See API_SETUP.md.
        if settings.dev_expose_reset_token:
            response["dev_reset_token"] = token
        else:
            log.info("password reset requested; configure an email provider to deliver it")
    return response


@router.post("/reset-password", dependencies=[Depends(limit("password-reset", 10, 3600))])
def reset_password(body: ResetPasswordIn, db: Session = Depends(get_db)):
    if not password_is_strong(body.new_password):
        raise errors.unprocessable(f"Password must be {PASSWORD_RULES}.", {"field": "new_password"})
    record = db.scalar(select(PasswordResetToken).where(PasswordResetToken.token_hash == hash_token(body.token)))
    now = datetime.now(timezone.utc)
    if record is None or record.used_at or (record.expires_at.replace(tzinfo=timezone.utc) if record.expires_at.tzinfo is None else record.expires_at) < now:
        raise errors.bad_request("This reset link is invalid or has expired.", code="invalid_token")
    user = db.get(User, record.user_id)
    user.password_hash = hash_password(body.new_password)
    record.used_at = now
    for session in db.scalars(select(AuthSession).where(AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None))):
        session.revoked_at = now
    audit(db, None, "password_reset_completed", "user", user.id)
    db.commit()
    return {"message": "Your password has been updated. Please sign in."}


@router.post("/change-password")
def change_password(body: ChangePasswordIn, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    if not verify_password(body.current_password, current.user.password_hash):
        raise errors.unprocessable("Current password is incorrect.", {"field": "current_password"})
    if not password_is_strong(body.new_password):
        raise errors.unprocessable(f"Password must be {PASSWORD_RULES}.", {"field": "new_password"})
    current.user.password_hash = hash_password(body.new_password)
    audit(db, current, "password_changed", "user", current.id)
    db.commit()
    return {"message": "Password updated."}

"""Heart disease risk screening assessments (supplied model susthiti-heart-v3, trained on
synthetic data -- a screening signal, never a diagnosis). Mirrors routers/diabetes_risk.py.

Readers: the patient, doctors with approved access, admins (read-only). A bare POST (no body)
refreshes using only what SUSTHITI already knows; a POST with `fields` is the assessment
questionnaire submission and always creates a new assessment. A GET never calls the model."""

from typing import Any

from fastapi import APIRouter, Depends, Query, Response
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, require_clinical, require_record_reader
from ..models import HeartRiskAssessment
from ..services.heart_risk import coordinator, presentation
from ..services.rate_limit import limit_by_user

router = APIRouter(tags=["heart risk"])

# Mirrors diabetes_risk.py's _PREDICT_LIMIT -- its own bucket so heavy use of one risk feature
# never eats into the other's budget. See docs/rate-limiting.md.
_PREDICT_LIMIT = Depends(limit_by_user("heart-risk-predict", 6, 600))


class HeartAssessmentIn(BaseModel):
    # feature -> answer, from the heart assessment form. Omit for a bare refresh.
    fields: dict[str, Any] = Field(default_factory=dict)


@router.get("/patients/{patient_id}/heart-risk")
def heart_risk_status(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    return coordinator.status(db, authorize_patient(db, current, patient_id))


@router.post("/patients/{patient_id}/heart-risk", dependencies=[_PREDICT_LIMIT])
def refresh_heart_risk(
    patient_id: str, response: Response, body: HeartAssessmentIn = HeartAssessmentIn(), force: bool = Query(False),
    current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    assessment, created = coordinator.run(db, patient, current, manual_fields=body.fields or None, force=force)
    response.status_code = 201 if created else 200
    return {"created": created, "assessment": presentation.assessment_out(assessment), **{
        k: v for k, v in coordinator.status(db, patient).items() if k in ("stale", "stale_reasons", "history_total")}}


@router.get("/patients/{patient_id}/heart-risk/history")
def heart_risk_history(
    patient_id: str, limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    base = select(HeartRiskAssessment).where(HeartRiskAssessment.patient_id == patient.id)
    total = db.scalar(select(func.count()).select_from(base.subquery()))
    rows = db.scalars(base.order_by(HeartRiskAssessment.created_at.desc()).limit(limit).offset(offset))
    return {"items": [presentation.assessment_summary(a) for a in rows], "total": total}


@router.get("/heart-risk/{assessment_id}")
def heart_risk_detail(assessment_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    assessment = db.get(HeartRiskAssessment, assessment_id)
    if assessment is None:
        raise errors.not_found("Assessment")
    authorize_patient(db, current, assessment.patient_id)
    return presentation.assessment_out(assessment, include_inputs=True)

"""Future diabetes risk assessments (SUSTHITI Diabetes Risk API v4).

Readers: the patient, doctors with approved access, admins (read-only). Refresh: the patient or
a doctor with access. A GET never calls the model."""

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, require_clinical, require_record_reader
from ..models import DiabetesRiskAssessment
from ..services.diabetes_risk import coordinator, presentation
from ..services.rate_limit import limit_by_user

router = APIRouter(tags=["diabetes risk"])

# 6 predictions per 10 minutes per user: a real refresh is rare (new data/reports arriving, or
# correcting an input and resubmitting once or twice) -- generous for that, a real brake on a
# loop against the metered ML service. See docs/rate-limiting.md.
_PREDICT_LIMIT = Depends(limit_by_user("diabetes-risk-predict", 6, 600))


@router.get("/patients/{patient_id}/diabetes-risk")
def risk_status(patient_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    return coordinator.status(db, authorize_patient(db, current, patient_id))


@router.post("/patients/{patient_id}/diabetes-risk", dependencies=[_PREDICT_LIMIT])
def refresh_risk(patient_id: str, response: Response, force: bool = Query(False), current: CurrentUser = Depends(require_clinical), db: Session = Depends(get_db)):
    patient = authorize_patient(db, current, patient_id)
    assessment, created = coordinator.run(db, patient, current, force=force)
    response.status_code = 201 if created else 200
    return {"created": created, "assessment": presentation.assessment_out(assessment), **{
        k: v for k, v in coordinator.status(db, patient).items() if k in ("stale", "stale_reasons", "history_total")}}


@router.get("/patients/{patient_id}/diabetes-risk/history")
def risk_history(
    patient_id: str, limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    base = select(DiabetesRiskAssessment).where(DiabetesRiskAssessment.patient_id == patient.id)
    total = db.scalar(select(func.count()).select_from(base.subquery()))
    rows = db.scalars(base.order_by(DiabetesRiskAssessment.created_at.desc()).limit(limit).offset(offset))
    return {"items": [presentation.assessment_summary(a) for a in rows], "total": total}


@router.get("/diabetes-risk/{assessment_id}")
def risk_detail(assessment_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    assessment = db.get(DiabetesRiskAssessment, assessment_id)
    if assessment is None:
        raise errors.not_found("Assessment")
    authorize_patient(db, current, assessment.patient_id)
    return presentation.assessment_out(assessment, include_inputs=True)

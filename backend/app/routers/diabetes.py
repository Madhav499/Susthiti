"""Assessments from the earlier symptom-questionnaire model (retired; replaced by the future
diabetes risk model, routers/diabetes_risk.py). Kept read-only so a patient's history stays
complete; no new ones can be created."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, require_record_reader
from ..models import AISummary, DiabetesAssessment
from ..schemas import assessment_out, summary_out
from ..services.ai.services import LifestyleAIService

router = APIRouter(tags=["diabetes (earlier model)"])


@router.get("/patients/{patient_id}/assessments")
def list_assessments(
    patient_id: str, limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    base = select(DiabetesAssessment).where(DiabetesAssessment.patient_id == patient.id)
    total = db.scalar(select(func.count()).select_from(base.subquery()))
    rows = db.scalars(base.order_by(DiabetesAssessment.assessed_at.desc()).limit(limit).offset(offset))
    return {"items": [assessment_out(a) for a in rows], "total": total}


@router.get("/assessments/{assessment_id}")
def get_assessment(assessment_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    assessment = db.get(DiabetesAssessment, assessment_id)
    if assessment is None:
        raise errors.not_found("Assessment")
    authorize_patient(db, current, assessment.patient_id)
    interpretation = db.scalar(
        select(AISummary).where(AISummary.kind == "assessment_interpretation", AISummary.subject_id == assessment.id)
        .order_by(AISummary.generated_at.desc()).limit(1)
    )
    if interpretation is None:
        return assessment_out(assessment, None)
    stale = interpretation.prompt_version != LifestyleAIService.INTERPRETATION_PROMPT_VERSION
    return assessment_out(assessment, summary_out(interpretation, stale))

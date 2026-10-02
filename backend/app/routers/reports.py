from datetime import date, datetime, timezone

from fastapi import BackgroundTasks, APIRouter, Depends, File, Form, Query, UploadFile
from fastapi.responses import Response
from sqlalchemy import String, cast, func, or_, select
from sqlalchemy.orm import Session

from .. import errors
from ..config import get_settings
from ..db import get_db
from ..deps import CurrentUser, authorize_patient, require_clinical, require_record_reader
from ..models import AccessRequest, Doctor, Patient, Report
from ..schemas import REPORT_CATEGORIES, report_out
from ..services.health_data.report_extraction import extract_from_text, extract_in_background, needs_ai
from ..services.records import audit, next_code, notify
from ..services.storage import ALLOWED_REPORT_TYPES, get_storage, sha256, sniff_content_type

router = APIRouter(tags=["reports"])

CATEGORY_GROUPS = {
    "blood": ["full_body", "blood_report", "blood_glucose", "lipid_profile", "kidney_function", "liver_function"],
    "imaging": ["x_ray", "mri", "ct"],
}


def list_reports_query(patient_id: str, q: str | None, category: str | None, start: date | None, end: date | None):
    query = select(Report).where(Report.patient_id == patient_id)
    if category and category != "all":
        cats = CATEGORY_GROUPS.get(category, [category])
        # A report matches if any of its types is in the group (categories is a JSON list).
        query = query.where(or_(Report.category.in_(cats), *[cast(Report.categories, String).like(f'%"{c}"%') for c in cats]))
    if start:
        query = query.where(Report.report_date >= start)
    if end:
        query = query.where(Report.report_date <= end)
    if q:
        like = f"%{q.strip().lower()}%"
        query = query.where(or_(
            func.lower(Report.original_filename).like(like), func.lower(Report.description).like(like),
            func.lower(Report.category).like(like.replace(" ", "_")), func.lower(cast(Report.categories, String)).like(like.replace(" ", "_")),
            func.lower(Report.report_code).like(like),
        ))
    return query


@router.get("/patients/{patient_id}/reports")
def list_reports(
    patient_id: str,
    q: str | None = Query(None, max_length=100),
    category: str | None = None,
    start: date | None = None,
    end: date | None = None,
    sort: str = Query("newest", pattern="^(newest|oldest)$"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current: CurrentUser = Depends(require_record_reader),
    db: Session = Depends(get_db),
):
    """Metadata only; files are fetched individually on request."""
    patient = authorize_patient(db, current, patient_id)
    query = list_reports_query(patient.id, q, category, start, end)
    total = db.scalar(select(func.count()).select_from(query.subquery()))
    order = (Report.report_date.desc(), Report.uploaded_at.desc()) if sort == "newest" else (Report.report_date.asc(), Report.uploaded_at.asc())
    rows = db.scalars(query.order_by(*order).limit(limit).offset(offset))
    return {"items": [report_out(r) for r in rows], "total": total, "limit": limit, "offset": offset}


async def store_report(
    db: Session, current: CurrentUser, patient: Patient, category: str, report_date: date,
    description: str | None, file: UploadFile,
) -> Report:
    settings = get_settings()
    # One or more types, comma-separated ("full_body,hba1c"); the first is the primary type.
    categories = list(dict.fromkeys(c.strip() for c in category.split(",") if c.strip()))
    if not categories or any(c not in REPORT_CATEGORIES for c in categories):
        raise errors.unprocessable("Choose at least one valid report type.", {"field": "category"})
    today = datetime.now(timezone.utc).date()
    if report_date > today:
        raise errors.unprocessable("Report date can't be in the future.", {"field": "report_date"})
    if report_date.year < 1900:
        raise errors.unprocessable("Enter a valid report date.", {"field": "report_date"})
    if description and len(description) > 1000:
        raise errors.unprocessable("Description must be 1000 characters or fewer.", {"field": "description"})
    max_bytes = settings.max_upload_mb * 1024 * 1024
    data = await file.read(max_bytes + 1)
    if not data:
        raise errors.unprocessable("The selected file is empty.", {"field": "file"})
    if len(data) > max_bytes:
        raise errors.unprocessable(f"File must be {settings.max_upload_mb} MB or smaller.", {"field": "file"})
    content_type = sniff_content_type(data, file.filename or "", file.content_type)
    if content_type not in ALLOWED_REPORT_TYPES:
        raise errors.unprocessable("Upload a PDF or an image (JPEG, PNG, WebP, HEIC).", {"field": "file"})

    filename = (file.filename or "report").replace("/", "_").replace("\\", "_")[:255]
    ref = get_storage().save(f"reports/{patient.id}", data, ALLOWED_REPORT_TYPES[content_type])
    report = Report(
        report_code=next_code(db, "report", "R"), patient_id=patient.id, category=categories[0], categories=categories,
        report_date=report_date, uploaded_by_role=current.role, uploader_user_id=current.id,
        uploader_name=current.name, original_filename=filename, file_type=content_type,
        file_size=len(data), storage_ref=ref, sha256=sha256(data), description=(description or None),
    )
    db.add(report)
    db.flush()
    audit(db, current, "report_uploaded", "report", report.id, report.report_code, {"patient_code": patient.patient_code, "category": ",".join(categories)})
    # Read HbA1c / glucose results from the report's text now; scans go to the AI reader afterwards.
    extract_from_text(db, report, data)

    if current.role == "patient":
        doctor_users = db.scalars(
            select(Doctor.user_id).join(AccessRequest, AccessRequest.doctor_id == Doctor.id)
            .where(AccessRequest.patient_id == patient.id, AccessRequest.status == "approved")
        )
        for user_id in doctor_users:
            notify(db, user_id, "new_report", "New report", f"{patient.user.full_name} ({patient.patient_code}) uploaded a new report.", "report", report.id, patient.id)
    else:
        notify(db, patient.user_id, "new_report", "New report added", f"A new report was added to your record by {current.name} ({current.role}).", "report", report.id, patient.id)
    return report


@router.post("/patients/{patient_id}/reports", status_code=201)
async def upload_report(
    patient_id: str,
    category: str = Form(...),
    report_date: date = Form(...),
    description: str | None = Form(None),
    file: UploadFile = File(...),
    background: BackgroundTasks = None,
    current: CurrentUser = Depends(require_clinical),
    db: Session = Depends(get_db),
):
    patient = authorize_patient(db, current, patient_id)
    report = await store_report(db, current, patient, category, report_date, description, file)
    db.commit()
    if needs_ai(report) and background is not None:
        background.add_task(extract_in_background, report.id)
    return report_out(report)


def get_authorized_report(db: Session, current: CurrentUser, report_id: str) -> Report:
    report = db.get(Report, report_id)
    if report is None:
        raise errors.not_found("Report")
    authorize_patient(db, current, report.patient_id)
    return report


@router.get("/reports/{report_id}")
def get_report(report_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    return report_out(get_authorized_report(db, current, report_id))


@router.get("/reports/{report_id}/file")
def get_report_file(report_id: str, current: CurrentUser = Depends(require_record_reader), db: Session = Depends(get_db)):
    """Streams the ORIGINAL file after an authorization check. There is no public URL."""
    report = get_authorized_report(db, current, report_id)
    data = get_storage().read(report.storage_ref)
    audit(db, current, "report_file_accessed", "report", report.id, report.report_code)
    db.commit()
    safe_name = report.original_filename.encode("ascii", "ignore").decode() or "report"
    return Response(
        data, media_type=report.file_type,
        headers={"Content-Disposition": f'attachment; filename="{safe_name}"', "Cache-Control": "private, no-store"},
    )

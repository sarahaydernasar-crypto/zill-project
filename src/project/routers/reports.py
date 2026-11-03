import secrets
from datetime import datetime
from typing import Literal, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel
from sqlalchemy.orm import Session

from project.auth import require_admin
from project.database import get_db
from project.models import UserReportDB
from project.uploads import save_photo

router = APIRouter(prefix="/api/reports", tags=["Community Reports"])

ReportType = Literal["hot_area", "planting_site", "damaged_tree"]
ReportStatus = Literal["new", "in_review", "resolved", "rejected"]

# حروف لا تلتبس عند نسخ رمز المتابعة يدوياً
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def _new_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(8))


def _public(r: UserReportDB) -> dict:
    """ما يراه صاحب البلاغ عبر رمز المتابعة."""
    return {
        "tracking_code": r.tracking_code,
        "report_type": r.report_type,
        "area_name": r.area_name,
        "status": r.status,
        "admin_note": r.admin_note,
        "created_at": r.timestamp.isoformat() if r.timestamp else None,
        "updated_at": r.updated_at.isoformat() if r.updated_at else None,
    }


@router.post("/", status_code=201)
async def submit_report(
    report_type: ReportType = Form(...),
    area_name: str = Form(..., min_length=1, max_length=200),
    description: str = Form(..., min_length=3, max_length=2000),
    photo: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
):
    report = UserReportDB(
        tracking_code=_new_code(),
        report_type=report_type,
        area_name=area_name,
        report_text=description,
        photo=await save_photo(photo) if photo is not None else None,
        status="new",
    )
    db.add(report)
    db.commit()
    return {"tracking_code": report.tracking_code}


@router.get("/track/{code}")
def track_report(code: str, db: Session = Depends(get_db)):
    report = db.query(UserReportDB).filter(UserReportDB.tracking_code == code.strip().upper()).first()
    if report is None:
        raise HTTPException(status_code=404, detail="لا يوجد بلاغ بهذا الرمز")
    return _public(report)


@router.get("/")
def list_reports(db: Session = Depends(get_db), _: str = Depends(require_admin)):
    reports = db.query(UserReportDB).order_by(UserReportDB.timestamp.desc()).all()
    return [{**_public(r), "id": r.id, "description": r.report_text, "photo": r.photo} for r in reports]


class ReportUpdate(BaseModel):
    status: ReportStatus
    admin_note: Optional[str] = None


@router.patch("/{report_id}")
def update_report(
    report_id: int,
    data: ReportUpdate,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin),
):
    report = db.get(UserReportDB, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="البلاغ غير موجود")
    report.status = data.status
    report.admin_note = data.admin_note
    report.updated_at = datetime.utcnow()
    db.commit()
    return _public(report)

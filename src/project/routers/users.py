from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from ..database import get_db
from ..models import UserReportDB

router = APIRouter(
    prefix="/api/users",
    tags=["User Interactions"]
)

class UserReportRequest(BaseModel):
    user_name: str = "Anonymous"
    area_name: str
    comment: str

@router.post("/report", summary="Submit a User Feedback/Report")
def submit_report(data: UserReportRequest, db: Session = Depends(get_db)):
    new_report = UserReportDB(
        user_name=data.user_name,
        area_name=data.area_name,
        comment=data.comment
    )
    db.add(new_report)
    db.commit()
    db.refresh(new_report)
    return {"message": "Report submitted successfully", "report_id": new_report.id}

@router.get("/reports", summary="Get All User Reports")
def get_reports(db: Session = Depends(get_db)):
    reports = db.query(UserReportDB).all()
    return {"reports": reports}
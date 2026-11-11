from typing import Literal, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from project.auth import require_admin, require_user
from project.database import get_db
from project.models import PointEntryDB, RedemptionDB, User
from project.points import REDEEM_POINTS, balance, rules

router = APIRouter(prefix="/api/points", tags=["Green Points"])


@router.get("/rules")
def point_rules():
    return rules()


class RedeemRequest(BaseModel):
    reward: Literal["phone_credit", "store_discount"]
    phone: str = Field(pattern=r"^07\d{9}$")


@router.post("/redeem", status_code=201)
def redeem(data: RedeemRequest, user: User = Depends(require_user), db: Session = Depends(get_db)):
    # قفل صف المستخدم حتى لا يصرف طلبان متزامنان الرصيد نفسه
    db.query(User).filter(User.id == user.id).with_for_update().one()
    if balance(db, user.id) < REDEEM_POINTS:
        raise HTTPException(status_code=409, detail=f"رصيدك أقل من {REDEEM_POINTS} نقطة")
    request = RedemptionDB(
        user_id=user.id, reward=data.reward, points=REDEEM_POINTS, phone=data.phone, status="pending"
    )
    db.add(request)
    db.flush()
    db.add(PointEntryDB(
        user_id=user.id,
        points=-REDEEM_POINTS,
        reason="طلب استبدال نقاط",
        source=f"redeem:{request.id}",
    ))
    db.commit()
    return {"id": request.id, "status": request.status}


@router.get("/redemptions")
def list_redemptions(db: Session = Depends(get_db), _: str = Depends(require_admin)):
    rows = (
        db.query(RedemptionDB, User.username)
        .join(User, RedemptionDB.user_id == User.id)
        .filter(RedemptionDB.status == "pending")
        .order_by(RedemptionDB.created_at)
        .all()
    )
    return [
        {
            "id": r.id,
            "username": username,
            "reward": r.reward,
            "points": r.points,
            "phone": r.phone,
            "status": r.status,
            "created_at": r.created_at.isoformat(),
        }
        for r, username in rows
    ]


class RedemptionUpdate(BaseModel):
    status: Literal["completed", "rejected"]
    admin_note: Optional[str] = Field(default=None, max_length=1000)


@router.patch("/redemptions/{redemption_id}")
def update_redemption(
    redemption_id: int,
    data: RedemptionUpdate,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin),
):
    request = db.get(RedemptionDB, redemption_id)
    if request is None:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    if request.status != "pending":
        raise HTTPException(status_code=409, detail="تمت معالجة هذا الطلب من قبل")
    request.status = data.status
    request.admin_note = data.admin_note
    if data.status == "rejected":
        db.add(PointEntryDB(
            user_id=request.user_id,
            points=request.points,
            reason="إعادة نقاط طلب استبدال مرفوض",
            source=f"refund:{request.id}",
        ))
    db.commit()
    return {"id": request.id, "status": request.status}

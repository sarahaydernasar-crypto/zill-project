from datetime import date, datetime, timedelta
from typing import Literal, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from project.auth import require_admin, require_user
from project.database import get_db
from project.models import TreeDB, TreeUpdateDB, User
from project.points import UPDATE_INTERVAL_DAYS, award_tree_groups, award_update
from project.rate_limit import rate_limit
from project.uploads import save_photo

router = APIRouter(prefix="/api/trees", tags=["Registered Trees"])

TreeStatus = Literal["healthy", "needs_care", "dead"]

# حدود تقريبية لمحافظة بغداد
_LAT_RANGE = (32.7, 33.8)
_LNG_RANGE = (43.8, 45.0)


def _update_to_dict(u: TreeUpdateDB, include_review: bool) -> dict:
    update = {
        "id": u.id,
        "status": u.status,
        "note": u.note,
        "photo": u.photo,
        "created_at": u.created_at.isoformat(),
    }
    if include_review:
        update.update(review_status=u.review_status, admin_note=u.admin_note)
    return update


def tree_to_dict(db: Session, t: TreeDB, include_review: bool = False) -> dict:
    updates = db.query(TreeUpdateDB).filter(TreeUpdateDB.tree_id == t.id)
    if not include_review:
        updates = updates.filter(TreeUpdateDB.review_status == "approved")
    tree = {
        "id": t.id,
        "name": t.name,
        "lat": t.lat,
        "lng": t.lng,
        "planted_on": t.planted_on.isoformat(),
        "status": t.status,
        "contributor": t.contributor,
        "photo": t.photo,
        "updates": [_update_to_dict(u, include_review) for u in updates.order_by(TreeUpdateDB.created_at).all()],
    }
    if include_review:
        tree.update(review_status=t.review_status, admin_note=t.admin_note)
    return tree


@router.get("/")
def list_trees(db: Session = Depends(get_db)):
    trees = db.query(TreeDB).filter(TreeDB.review_status == "approved").order_by(TreeDB.planted_on.desc()).all()
    return [tree_to_dict(db, t) for t in trees]


@router.post("/", status_code=201, dependencies=[Depends(rate_limit(30, 3600))])
async def register_tree(
    name: str = Form(..., min_length=2, max_length=100),
    lat: float = Form(...),
    lng: float = Form(...),
    planted_on: date = Form(...),
    contributor: Optional[str] = Form(None, max_length=100),
    photo: UploadFile = File(...),
    user: User = Depends(require_user),
    db: Session = Depends(get_db),
):
    if not (_LAT_RANGE[0] <= lat <= _LAT_RANGE[1] and _LNG_RANGE[0] <= lng <= _LNG_RANGE[1]):
        raise HTTPException(status_code=422, detail="يجب أن يكون موقع الشجرة داخل بغداد")
    if planted_on > date.today():
        raise HTTPException(status_code=422, detail="تاريخ الزراعة لا يمكن أن يكون في المستقبل")
    tree = TreeDB(
        user_id=user.id,
        name=name.strip(),
        lat=lat,
        lng=lng,
        planted_on=planted_on,
        status="healthy",
        contributor=(contributor or "").strip() or user.username,
        photo=await save_photo(photo, db),
        review_status="pending",
    )
    db.add(tree)
    db.commit()
    return tree_to_dict(db, tree, include_review=True)


@router.post("/{tree_id}/updates", status_code=201, dependencies=[Depends(rate_limit(30, 3600))])
async def add_update(
    tree_id: int,
    status: TreeStatus = Form(...),
    note: Optional[str] = Form(None, max_length=1000),
    photo: UploadFile = File(...),
    user: User = Depends(require_user),
    db: Session = Depends(get_db),
):
    tree = db.get(TreeDB, tree_id)
    if tree is None or tree.user_id != user.id:
        raise HTTPException(status_code=404, detail="الشجرة غير موجودة")
    if tree.review_status != "approved":
        raise HTTPException(status_code=409, detail="لا يمكن إضافة متابعة قبل اعتماد الشجرة")
    since = datetime.utcnow() - timedelta(days=UPDATE_INTERVAL_DAYS)
    recent = db.query(TreeUpdateDB).filter(
        TreeUpdateDB.tree_id == tree.id,
        TreeUpdateDB.review_status != "rejected",
        TreeUpdateDB.created_at > since,
    )
    if recent.first() is not None:
        raise HTTPException(status_code=409, detail=f"يمكن إرسال متابعة واحدة كل {UPDATE_INTERVAL_DAYS} يوماً لكل شجرة")
    update = TreeUpdateDB(
        tree_id=tree.id, status=status, note=note, photo=await save_photo(photo, db), review_status="pending"
    )
    db.add(update)
    db.commit()
    return _update_to_dict(update, include_review=True)


class Review(BaseModel):
    decision: Literal["approved", "rejected"]
    admin_note: Optional[str] = Field(default=None, max_length=1000)


@router.get("/pending")
def pending_reviews(db: Session = Depends(get_db), _: str = Depends(require_admin)):
    trees = db.query(TreeDB).filter(TreeDB.review_status == "pending").order_by(TreeDB.created_at).all()
    updates = (
        db.query(TreeUpdateDB, TreeDB.name)
        .join(TreeDB, TreeUpdateDB.tree_id == TreeDB.id)
        .filter(TreeUpdateDB.review_status == "pending")
        .order_by(TreeUpdateDB.created_at)
        .all()
    )
    return {
        "trees": [tree_to_dict(db, t, include_review=True) for t in trees],
        "updates": [{**_update_to_dict(u, include_review=True), "tree_name": name} for u, name in updates],
    }


@router.patch("/{tree_id}/review")
def review_tree(tree_id: int, data: Review, db: Session = Depends(get_db), _: str = Depends(require_admin)):
    tree = db.get(TreeDB, tree_id)
    if tree is None:
        raise HTTPException(status_code=404, detail="الشجرة غير موجودة")
    if tree.review_status != "pending":
        raise HTTPException(status_code=409, detail="تمت مراجعة هذه الشجرة من قبل")
    tree.review_status = data.decision
    tree.admin_note = data.admin_note
    if data.decision == "approved":
        award_tree_groups(db, tree.user_id)
    db.commit()
    return tree_to_dict(db, tree, include_review=True)


@router.patch("/updates/{update_id}/review")
def review_update(update_id: int, data: Review, db: Session = Depends(get_db), _: str = Depends(require_admin)):
    update = db.get(TreeUpdateDB, update_id)
    if update is None:
        raise HTTPException(status_code=404, detail="المتابعة غير موجودة")
    if update.review_status != "pending":
        raise HTTPException(status_code=409, detail="تمت مراجعة هذه المتابعة من قبل")
    update.review_status = data.decision
    update.admin_note = data.admin_note
    if data.decision == "approved":
        tree = db.get(TreeDB, update.tree_id)
        tree.status = update.status
        award_update(db, tree, update)
    db.commit()
    return _update_to_dict(update, include_review=True)

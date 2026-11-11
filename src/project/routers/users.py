import bcrypt
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from project.auth import create_token, require_user
from project.database import get_db
from project.models import PointEntryDB, RedemptionDB, TreeDB, User
from project.points import balance
from project.rate_limit import rate_limit
from project.routers.auth import password_matches
from project.routers.trees import tree_to_dict

router = APIRouter(prefix="/api/users", tags=["User Accounts"])


class Registration(BaseModel):
    username: str = Field(min_length=3, max_length=30, pattern=r"^[\w.-]+$")
    password: str = Field(min_length=8, max_length=72)


class LoginRequest(BaseModel):
    username: str
    password: str


def _session(user: User) -> dict:
    return {"token": create_token(user.username, role="user"), "username": user.username}


@router.post("/register", status_code=201, dependencies=[Depends(rate_limit(10, 3600))])
def register(data: Registration, db: Session = Depends(get_db)):
    password = data.password.encode("utf-8")
    if len(password) > 72:  # حد bcrypt بالبايت، والأحرف العربية أكثر من بايت
        raise HTTPException(status_code=422, detail="كلمة المرور طويلة جداً")
    if db.query(User).filter(func.lower(User.username) == data.username.lower()).first() is not None:
        raise HTTPException(status_code=409, detail="اسم المستخدم مستخدم من قبل")
    user = User(
        username=data.username,
        hashed_password=bcrypt.hashpw(password, bcrypt.gensalt()).decode("utf-8"),
        is_admin=False,
    )
    db.add(user)
    db.commit()
    return _session(user)


@router.post("/login", dependencies=[Depends(rate_limit(10, 300))])
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()
    if user is None or user.is_admin or not password_matches(data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="اسم المستخدم أو كلمة المرور غير صحيحة")
    return _session(user)


@router.get("/me")
def my_dashboard(user: User = Depends(require_user), db: Session = Depends(get_db)):
    entries = (
        db.query(PointEntryDB)
        .filter(PointEntryDB.user_id == user.id)
        .order_by(PointEntryDB.created_at.desc(), PointEntryDB.id.desc())
        .all()
    )
    trees = db.query(TreeDB).filter(TreeDB.user_id == user.id).order_by(TreeDB.created_at.desc()).all()
    redemptions = (
        db.query(RedemptionDB)
        .filter(RedemptionDB.user_id == user.id)
        .order_by(RedemptionDB.created_at.desc())
        .all()
    )
    return {
        "username": user.username,
        "balance": balance(db, user.id),
        "entries": [
            {"points": e.points, "reason": e.reason, "created_at": e.created_at.isoformat()} for e in entries
        ],
        "trees": [tree_to_dict(db, t, include_review=True) for t in trees],
        "redemptions": [
            {
                "id": r.id,
                "reward": r.reward,
                "points": r.points,
                "status": r.status,
                "admin_note": r.admin_note,
                "created_at": r.created_at.isoformat(),
            }
            for r in redemptions
        ],
    }

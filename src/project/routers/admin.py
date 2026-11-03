from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from project.auth import require_admin
from project.database import get_db
from project.models import User

router = APIRouter(prefix="/admin", tags=["Admin"], dependencies=[Depends(require_admin)])

@router.get("/users")
def get_all_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    # لا نُرجع كلمات المرور المشفرة في الاستجابة
    return [{"id": u.id, "username": u.username, "is_admin": u.is_admin} for u in users]

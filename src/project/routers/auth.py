import bcrypt
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from project.auth import create_token
from project.database import get_db
from project.models import User

router = APIRouter(prefix="/api/auth", tags=["Admin Login"])

MIN_PASSWORD_LENGTH = 12


class LoginRequest(BaseModel):
    username: str
    password: str


@router.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()
    valid = user is not None and user.is_admin and bcrypt.checkpw(
        data.password.encode("utf-8"), user.hashed_password.encode("utf-8")
    )
    if not valid:
        raise HTTPException(status_code=401, detail="اسم المستخدم أو كلمة المرور غير صحيحة")
    # كلمات المرور القصيرة القديمة لا تُقبل حتى يغيّرها set_admin_password.py
    if len(data.password) < MIN_PASSWORD_LENGTH:
        raise HTTPException(status_code=403, detail="كلمة المرور ضعيفة. غيّرها بالأمر: uv run python src/set_admin_password.py")
    return {"token": create_token(user.username), "username": user.username}

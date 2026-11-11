import bcrypt
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from project.auth import create_token
from project.database import get_db
from project.models import User
from project.rate_limit import rate_limit

router = APIRouter(prefix="/api/auth", tags=["Admin Login"])

MIN_PASSWORD_LENGTH = 12


class LoginRequest(BaseModel):
    username: str
    password: str


def password_matches(password: str, stored: str | None) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), (stored or "").encode("utf-8"))
    except ValueError:
        # القيمة المحفوظة ليست تشفير bcrypt (حساب قديم بنص مكشوف): لا يُقبل حتى تُغيَّر كلمة مروره
        return False


@router.post("/login", dependencies=[Depends(rate_limit(10, 300))])
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()
    if user is None or not user.is_admin or not password_matches(data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="اسم المستخدم أو كلمة المرور غير صحيحة")
    # كلمات المرور القصيرة القديمة لا تُقبل حتى يغيّرها set_admin_password.py
    if len(data.password) < MIN_PASSWORD_LENGTH:
        raise HTTPException(status_code=403, detail="كلمة المرور ضعيفة. غيّرها بالأمر: uv run python src/set_admin_password.py")
    return {"token": create_token(user.username), "username": user.username}

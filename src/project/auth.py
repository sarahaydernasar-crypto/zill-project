import os
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from project.database import get_db
from project.models import User

TOKEN_HOURS = 8
_bearer = HTTPBearer(auto_error=False)


def _secret() -> str:
    secret = os.getenv("ADMIN_TOKEN_SECRET")
    if not secret:
        raise RuntimeError("ADMIN_TOKEN_SECRET غير موجود. أضفه إلى ملف .env")
    return secret


def create_token(username: str, role: str = "admin") -> str:
    expires = datetime.now(timezone.utc) + timedelta(hours=TOKEN_HOURS)
    return jwt.encode({"sub": username, "role": role, "exp": expires}, _secret(), algorithm="HS256")


def _claims(credentials: HTTPAuthorizationCredentials, role: str) -> dict:
    try:
        claims = jwt.decode(credentials.credentials, _secret(), algorithms=["HS256"])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="انتهت الجلسة، سجّل الدخول مرة أخرى")
    if claims.get("role") != role:
        raise HTTPException(status_code=403, detail="ليست لديك صلاحية لهذا الإجراء")
    return claims


def require_admin(credentials: HTTPAuthorizationCredentials = Depends(_bearer)) -> str:
    """يسمح بالطلب فقط مع رمز مشرف صالح، ويعيد اسم المشرف."""
    if credentials is None:
        raise HTTPException(status_code=401, detail="يلزم تسجيل دخول المشرف")
    return _claims(credentials, "admin")["sub"]


def optional_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User | None:
    """يعيد صاحب الجلسة إن وُجدت، ويبقى الطلب بلا رمز مسموحاً."""
    if credentials is None:
        return None
    user = db.query(User).filter(User.username == _claims(credentials, "user")["sub"]).first()
    if user is None or user.is_admin:
        raise HTTPException(status_code=401, detail="انتهت الجلسة، سجّل الدخول مرة أخرى")
    return user


def require_user(user: User | None = Depends(optional_user)) -> User:
    if user is None:
        raise HTTPException(status_code=401, detail="يلزم تسجيل الدخول")
    return user

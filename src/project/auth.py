import os
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

TOKEN_HOURS = 8
_bearer = HTTPBearer(auto_error=False)


def _secret() -> str:
    secret = os.getenv("ADMIN_TOKEN_SECRET")
    if not secret:
        raise RuntimeError("ADMIN_TOKEN_SECRET غير موجود. أضفه إلى ملف .env")
    return secret


def create_token(username: str) -> str:
    expires = datetime.now(timezone.utc) + timedelta(hours=TOKEN_HOURS)
    return jwt.encode({"sub": username, "exp": expires}, _secret(), algorithm="HS256")


def require_admin(credentials: HTTPAuthorizationCredentials = Depends(_bearer)) -> str:
    """يسمح بالطلب فقط مع رمز مشرف صالح، ويعيد اسم المشرف."""
    if credentials is None:
        raise HTTPException(status_code=401, detail="يلزم تسجيل دخول المشرف")
    try:
        return jwt.decode(credentials.credentials, _secret(), algorithms=["HS256"])["sub"]
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="انتهت الجلسة، سجّل الدخول مرة أخرى")

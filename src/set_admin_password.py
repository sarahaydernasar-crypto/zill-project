"""يغيّر كلمة مرور مشرف، أو ينشئ مشرفاً جديداً إذا لم يكن موجوداً.

uv run python src/set_admin_password.py
"""
from getpass import getpass

import bcrypt

from project.database import SessionLocal, ensure_schema
from project.models import User
from project.routers.auth import MIN_PASSWORD_LENGTH


def main():
    ensure_schema()
    username = input("اسم المشرف: ").strip()
    password = getpass(f"كلمة المرور الجديدة ({MIN_PASSWORD_LENGTH} حرفاً على الأقل): ")
    if len(password) < MIN_PASSWORD_LENGTH:
        raise SystemExit("كلمة المرور قصيرة، لم يتغير شيء.")
    if password != getpass("أعد كتابتها: "):
        raise SystemExit("الكلمتان غير متطابقتين، لم يتغير شيء.")

    hashed = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.username == username).first()
        if user is None:
            db.add(User(username=username, hashed_password=hashed, is_admin=True))
        else:
            user.hashed_password = hashed
            user.is_admin = True
        db.commit()
    finally:
        db.close()
    print(f"تم حفظ كلمة مرور المشرف {username}.")


if __name__ == "__main__":
    main()

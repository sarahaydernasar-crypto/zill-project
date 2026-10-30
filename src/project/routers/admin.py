from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from project.database import SessionLocal
from project.models import User, AdminLogDB

router = APIRouter(prefix="/admin", tags=["Admin"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/users")
def get_all_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return users
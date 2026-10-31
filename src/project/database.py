import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

# رابط قاعدة البيانات يُقرأ من ملف .env (غير مرفوع على Git) أو من متغيرات البيئة
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL غير موجود. أنشئ ملف .env بالاعتماد على .env.example")

# إنشاء محرك الاتصال بقاعدة بيانات PostgreSQL (Neon) مع إعدادات الأمان
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def ensure_schema():
    """يضيف الأعمدة الجديدة إلى الجداول الموجودة دون حذف أي بيانات."""
    insp = inspect(engine)
    if "areas" not in insp.get_table_names():
        return
    columns = {c["name"] for c in insp.get_columns("areas")}
    if "geometry" not in columns:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE areas ADD COLUMN geometry TEXT"))

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

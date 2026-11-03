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
    """ينشئ الجداول الناقصة ويضيف الأعمدة الجديدة دون حذف أي بيانات."""
    Base.metadata.create_all(bind=engine)
    insp = inspect(engine)
    new_columns = {
        "areas": {
            "geometry": "TEXT",
            "built_up_ratio": "FLOAT",
            "water_distance_m": "FLOAT",
            "soil_water": "FLOAT",
        },
        "user_reports": {
            "tracking_code": "VARCHAR",
            "report_type": "VARCHAR",
            "photo": "VARCHAR",
            "status": "VARCHAR",
            "admin_note": "VARCHAR",
            "updated_at": "TIMESTAMP",
        },
    }
    with engine.begin() as conn:
        for table, columns in new_columns.items():
            existing = {c["name"] for c in insp.get_columns(table)}
            for name, sql_type in columns.items():
                if name not in existing:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {sql_type}"))

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

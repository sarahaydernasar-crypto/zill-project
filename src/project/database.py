import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# رابط اتصال سحابة Neon (يمكنك استبداله بالرابط المباشر أو جلبه من متغيرات البيئة Environment Variables)
DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql://neondb_owner:npg_cLC3AOamIfY6@ep-morning-paper-b5xyoaxp-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
)

# إنشاء محرك الاتصال بقاعدة بيانات PostgreSQL (Neon) مع إعدادات الأمان
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
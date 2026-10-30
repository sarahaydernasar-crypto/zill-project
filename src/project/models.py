from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime
from datetime import datetime
from project.database import Base

# 1. جدول المناطق والتحليلات المكانية لبغداد
class AreaDB(Base):
    __tablename__ = "areas"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    temperature = Column(Float)
    classification = Column(String)
    ndvi = Column(Float)
    planting_priority = Column(Float)

# 2. جدول المستخدمين والأدمن
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_admin = Column(Boolean, default=False)

# 3. جدول سجلات الأدمن
class AdminLogDB(Base):
    __tablename__ = "admin_logs"

    id = Column(Integer, primary_key=True, index=True)
    action = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)
    admin_username = Column(String)

# 4. جدول تقارير المستخدمين (المطلوب في ملف users.py)
class UserReportDB(Base):
    __tablename__ = "user_reports"

    id = Column(Integer, primary_key=True, index=True)
    report_text = Column(String)
    username = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)
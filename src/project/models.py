from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Text
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
    geometry = Column(Text, nullable=True)  # حدود المنطقة بصيغة GeoJSON (نص) لعرضها على الخريطة

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
    username = Column(String)
    area_name = Column(String)
    report_text = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)

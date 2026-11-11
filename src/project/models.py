from sqlalchemy import Column, ForeignKey, Integer, String, Float, Boolean, Date, DateTime, LargeBinary, Text
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
    built_up_ratio = Column(Float, nullable=True)    # نسبة المساحة المبنية (0-1)
    water_distance_m = Column(Float, nullable=True)  # متوسط البعد عن المياه السطحية بالمتر
    soil_water = Column(Float, nullable=True)        # قدرة التربة على حفظ الماء (0-1)
    geometry = Column(Text, nullable=True)  # حدود المنطقة بصيغة GeoJSON (نص) لعرضها على الخريطة

# المناطق داخل كل قضاء (أحياء أو نواحٍ)، بالأرقام نفسها المحسوبة للأقضية
class SubAreaDB(Base):
    __tablename__ = "sub_areas"

    id = Column(Integer, primary_key=True, index=True)
    district = Column(String, index=True)
    name = Column(String)
    level = Column(String)  # حي أو ناحية
    temperature = Column(Float)
    classification = Column(String)
    ndvi = Column(Float)
    planting_priority = Column(Float)
    built_up_ratio = Column(Float)
    water_distance_m = Column(Float)
    soil_water = Column(Float)
    geometry = Column(Text, nullable=True)

# مواقع تشجير محتملة داخل الأقضية (من التحليل المكاني)
class PlantingSiteDB(Base):
    __tablename__ = "planting_sites"

    id = Column(Integer, primary_key=True, index=True)
    district = Column(String, index=True)
    place = Column(String, nullable=True)  # أقرب حي أو شارع من OpenStreetMap
    lat = Column(Float)
    lng = Column(Float)
    area_ha = Column(Float)
    temperature = Column(Float)
    ndvi = Column(Float)
    planting_priority = Column(Float)
    water_distance_m = Column(Float)
    geometry = Column(Text, nullable=True)

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

# 4. بلاغات المجتمع
class UserReportDB(Base):
    __tablename__ = "user_reports"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, nullable=True)
    area_name = Column(String)
    report_text = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)
    tracking_code = Column(String, unique=True, index=True)  # رمز المتابعة بلا حساب
    report_type = Column(String)  # hot_area أو planting_site أو damaged_tree
    photo = Column(String, nullable=True)
    status = Column(String, default="new")  # new أو in_review أو resolved أو rejected
    admin_note = Column(String, nullable=True)
    updated_at = Column(DateTime, nullable=True)

# 5. حملات التشجير المنفذة، مع قياسها قبل الزراعة وبعدها من الأقمار الصناعية
class CampaignDB(Base):
    __tablename__ = "campaigns"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    area_name = Column(String)
    lat = Column(Float)
    lng = Column(Float)
    radius_m = Column(Float, default=100)
    planted_on = Column(Date)
    trees_planted = Column(Integer)
    trees_alive = Column(Integer, nullable=True)
    tree_species = Column(String, nullable=True)
    condition = Column(String, default="unknown")
    notes = Column(String, nullable=True)
    photo_before = Column(String, nullable=True)
    photo_after = Column(String, nullable=True)
    # تملؤها campaign_impact.py
    period_before = Column(String, nullable=True)
    period_after = Column(String, nullable=True)
    ndvi_before = Column(Float, nullable=True)
    ndvi_after = Column(Float, nullable=True)
    temp_before = Column(Float, nullable=True)
    temp_after = Column(Float, nullable=True)
    green_ha_before = Column(Float, nullable=True)
    green_ha_after = Column(Float, nullable=True)
    ref_ndvi_before = Column(Float, nullable=True)
    ref_ndvi_after = Column(Float, nullable=True)
    ref_temp_before = Column(Float, nullable=True)
    ref_temp_after = Column(Float, nullable=True)
    measured_at = Column(DateTime, nullable=True)

# صور البلاغات والحملات والأشجار
class PhotoDB(Base):
    __tablename__ = "photos"

    name = Column(String, primary_key=True)
    media_type = Column(String)
    data = Column(LargeBinary)
    created_at = Column(DateTime, default=datetime.utcnow)

# 6. الأشجار التي يسجلها المستخدمون، وتظهر على الخريطة بعد اعتماد المشرف
class TreeDB(Base):
    __tablename__ = "trees"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    name = Column(String)
    lat = Column(Float)
    lng = Column(Float)
    planted_on = Column(Date)
    status = Column(String, default="healthy")  # healthy أو needs_care أو dead
    contributor = Column(String)  # الشخص أو الفريق المساهم
    photo = Column(String)
    review_status = Column(String, default="pending", index=True)  # pending أو approved أو rejected
    admin_note = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

# 7. سجل متابعة نمو الشجرة
class TreeUpdateDB(Base):
    __tablename__ = "tree_updates"

    id = Column(Integer, primary_key=True, index=True)
    tree_id = Column(Integer, ForeignKey("trees.id"), index=True)
    status = Column(String)
    note = Column(String, nullable=True)
    photo = Column(String)
    review_status = Column(String, default="pending", index=True)
    admin_note = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

# 8. حركات النقاط: الرصيد مجموعها، والمصدر الفريد يمنع منح النقاط مرتين عن الشيء نفسه
class PointEntryDB(Base):
    __tablename__ = "point_entries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    points = Column(Integer)
    reason = Column(String)
    source = Column(String, unique=True)
    created_at = Column(DateTime, default=datetime.utcnow)

# 9. طلبات استبدال النقاط، وينفذها المشرف يدوياً
class RedemptionDB(Base):
    __tablename__ = "redemptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    reward = Column(String)  # phone_credit أو store_discount
    points = Column(Integer)
    phone = Column(String)
    status = Column(String, default="pending", index=True)  # pending أو completed أو rejected
    admin_note = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

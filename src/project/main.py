from fastapi import FastAPI, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
import os

from project.database import get_db
from project.models import AreaDB
from project.routers import areas, admin, users  # استدعاء مسارات الأدمن والمستخدمين والمناطق

app = FastAPI(title="Zill Project API", version="1.0")

# تضمين جميع الـ Routers لتظهر في واجهة Swagger
app.include_router(areas.router)
app.include_router(admin.router)
app.include_router(users.router)

@app.get("/")
def read_root():
    return {"message": "Welcome to Zill Project API - Baghdad Spatial Analysis"}

# مسار جلب مناطق بغداد والتحليلات من قاعدة بيانات Neon
@app.get("/api/areas/")
def get_spatial_areas(db: Session = Depends(get_db)):
    areas = db.query(AreaDB).all()
    return areas

# مسار عرض خريطة بغداد التفاعلية (HTML)
@app.get("/map", response_class=HTMLResponse)
def show_baghdad_map():
    file_path = "src/project/data anlaysis/baghdad_heat_and_ndvi.html"
    
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()
            
    return "<h3>عذراً، ملف الخريطة غير موجود. يرجى التأكد من تشغيل سكربت التحليل في مجلد data anlaysis.</h3>"
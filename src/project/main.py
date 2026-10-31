from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from project.database import ensure_schema
from project.routers import areas, admin, users  # استدعاء مسارات الأدمن والمستخدمين والمناطق

ensure_schema()  # إضافة عمود geometry لقاعدة البيانات القديمة إن لم يكن موجوداً

PROJECT_DIR = Path(__file__).resolve().parent          # src/project
ROOT_DIR = PROJECT_DIR.parents[1]                      # zill-project

app = FastAPI(title="Zill Project API", version="1.0")

# تضمين جميع الـ Routers لتظهر في واجهة Swagger
# (مسار /api/areas/ موجود في routers/areas.py)
app.include_router(areas.router)
app.include_router(admin.router)
app.include_router(users.router)

# السماح لواجهة ظِلّ (الويب وتطبيق Flutter) بالاتصال بالـ API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# خدمة واجهة الويب على الرابط /app
FRONTEND_DIR = ROOT_DIR / "frontend"
if FRONTEND_DIR.exists():
    app.mount("/app", StaticFiles(directory=FRONTEND_DIR, html=True), name="frontend")

@app.get("/")
def read_root():
    return {"message": "Welcome to Zill Project API - Baghdad Spatial Analysis"}

# مسار عرض خريطة بغداد التفاعلية (HTML)
@app.get("/map", response_class=HTMLResponse)
def show_baghdad_map():
    file_path = PROJECT_DIR / "data anlaysis" / "baghdad_heat_and_ndvi.html"

    if file_path.exists():
        return file_path.read_text(encoding="utf-8")

    return "<h3>عذراً، ملف الخريطة غير موجود. يرجى التأكد من تشغيل سكربت التحليل في مجلد data anlaysis.</h3>"

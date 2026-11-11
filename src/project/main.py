from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import HTMLResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from sqlalchemy.orm import Session

from project.database import ensure_schema, get_db
from project.models import PhotoDB
from project.routers import areas, admin, auth, campaigns, green_points, reports, sites, trees, users  # استدعاء مسارات الأدمن والمستخدمين والمناطق

ensure_schema()  # إضافة الجداول والأعمدة الجديدة لقاعدة البيانات القديمة إن لم تكن موجودة

PROJECT_DIR = Path(__file__).resolve().parent          # src/project
ROOT_DIR = PROJECT_DIR.parents[1]                      # zill-project

app = FastAPI(title="Zill Project API", version="1.0")

# تضمين جميع الـ Routers لتظهر في واجهة Swagger
# (مسار /api/areas/ موجود في routers/areas.py)
app.include_router(areas.router)
app.include_router(sites.router)
app.include_router(admin.router)
app.include_router(auth.router)
app.include_router(reports.router)
app.include_router(campaigns.router)
app.include_router(users.router)
app.include_router(trees.router)
app.include_router(green_points.router)

# السماح لواجهة ظِلّ (الويب وتطبيق Flutter) بالاتصال بالـ API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# صور البلاغات والحملات والأشجار
@app.get("/uploads/{name}")
def get_photo(name: str, db: Session = Depends(get_db)):
    photo = db.get(PhotoDB, name)
    if photo is None:
        raise HTTPException(status_code=404, detail="الصورة غير موجودة")
    # اسم الصورة عشوائي ولا يتغير محتواها، فيمكن للمتصفح حفظها
    return Response(photo.data, media_type=photo.media_type, headers={"Cache-Control": "public, max-age=31536000, immutable"})

# خدمة واجهة الويب على الرابط /app
FRONTEND_DIR = ROOT_DIR / "frontend"
if FRONTEND_DIR.exists():
    app.mount("/app", StaticFiles(directory=FRONTEND_DIR, html=True), name="frontend")

WEB_DIR = ROOT_DIR / "web_dist"  # نسخة ويب من تطبيق Flutter
if not WEB_DIR.exists():
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

# يأتي أخيراً حتى لا يغطي مسارات الـ API
if WEB_DIR.exists():
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")

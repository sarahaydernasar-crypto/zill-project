import json
from pathlib import Path
from project.database import engine, SessionLocal, ensure_schema
from project.models import Base, AreaDB, PlantingSiteDB, SubAreaDB

RESULTS_FILE = Path(__file__).resolve().parents[1] / "baghdad_results.json"
SITES_FILE = Path(__file__).resolve().parents[1] / "baghdad_sites.json"
SUB_AREAS_FILE = Path(__file__).resolve().parents[1] / "baghdad_sub_areas.json"

# إنشاء الجداول الناقصة فقط؛ لا يُحذف أي جدول موجود
Base.metadata.create_all(bind=engine)
ensure_schema()

def seed_areas():
    with open(RESULTS_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    sites = None
    if SITES_FILE.exists():
        with open(SITES_FILE, "r", encoding="utf-8") as f:
            sites = json.load(f)

    sub_areas = None
    if SUB_AREAS_FILE.exists():
        with open(SUB_AREAS_FILE, "r", encoding="utf-8") as f:
            sub_areas = json.load(f)

    if not data:
        raise ValueError("ملف النتائج فارغ، لم يتم تغيير قاعدة البيانات.")

    db = SessionLocal()
    try:
        # استبدال جداول المناطق والمواقع فقط، في عملية واحدة: إما تنجح كلها أو لا يتغير شيء.
        # جداول المستخدمين والبلاغات والسجلات لا تُلمس.
        db.query(AreaDB).delete()
        for item in data:
            area = AreaDB(
                name=item["name"],
                temperature=float(item["temperature"]),
                classification=item["classification"],
                ndvi=float(item["ndvi"]),
                planting_priority=float(item["planting_priority"]),
                built_up_ratio=item.get("built_up_ratio"),
                water_distance_m=item.get("water_distance_m"),
                soil_water=item.get("soil_water"),
                geometry=json.dumps(item["geometry"]) if item.get("geometry") else None
            )
            db.add(area)
        if sites is not None:
            db.query(PlantingSiteDB).delete()
            for item in sites:
                fields = {k: v for k, v in item.items() if k != "geometry"}
                db.add(PlantingSiteDB(**fields, geometry=json.dumps(item["geometry"])))
        if sub_areas is not None:
            db.query(SubAreaDB).delete()
            for item in sub_areas:
                fields = {k: v for k, v in item.items() if k != "geometry"}
                db.add(SubAreaDB(**fields, geometry=json.dumps(item["geometry"])))
        db.commit()
        print(f"✨ تم تحديث {len(data)} قضاء و{len(sub_areas or [])} منطقة و{len(sites or [])} موقع تشجير بنجاح!")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

if __name__ == "__main__":
    seed_areas()

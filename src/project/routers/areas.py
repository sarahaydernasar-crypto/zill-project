import json
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from project.database import get_db
from project.models import AreaDB, SubAreaDB

router = APIRouter(
    prefix="/api/areas",
    tags=["Mobile App - Areas & Spatial Data"]
)

@router.get("/sub-areas", response_model=List[dict])
def get_sub_areas(db: Session = Depends(get_db)):
    """المناطق داخل كل قضاء (أحياء أو نواحٍ)"""
    return [
        {
            "id": a.id,
            "district": a.district,
            "name": a.name,
            "level": a.level,
            "temperature": a.temperature,
            "classification": a.classification,
            "ndvi": a.ndvi,
            "planting_priority": a.planting_priority,
            "built_up_ratio": a.built_up_ratio,
            "water_distance_m": a.water_distance_m,
            "soil_water": a.soil_water,
            "geometry": json.loads(a.geometry) if a.geometry else None,
        }
        for a in db.query(SubAreaDB).all()
    ]

@router.get("/", response_model=List[dict])
def get_all_spatial_areas(db: Session = Depends(get_db)):
    """
    جلب كافة مناطق بغداد مع درجات الحرارة ومؤشرات التشجير
    لتغذية واجهات تطبيق الموبايل والخريطة التفاعلية
    """
    areas = db.query(AreaDB).all()
    if not areas:
        return []

    result = []
    for area in areas:
        result.append({
            "id": area.id,
            "name": area.name,
            "temperature": area.temperature,
            "classification": area.classification,
            "ndvi": area.ndvi,
            "planting_priority": area.planting_priority,
            "built_up_ratio": area.built_up_ratio,
            "water_distance_m": area.water_distance_m,
            "soil_water": area.soil_water,
            "geometry": json.loads(area.geometry) if area.geometry else None,
        })
    return result

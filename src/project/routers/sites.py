import json
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from project.database import get_db
from project.models import PlantingSiteDB

router = APIRouter(
    prefix="/api/sites",
    tags=["Mobile App - Planting Sites"]
)

@router.get("/", response_model=List[dict])
def get_planting_sites(db: Session = Depends(get_db)):
    """المواقع المحتملة للتشجير داخل الأقضية، مرتبة حسب درجة الأولوية"""
    sites = db.query(PlantingSiteDB).order_by(PlantingSiteDB.planting_priority.desc()).all()
    return [
        {
            "id": s.id,
            "district": s.district,
            "place": s.place,
            "lat": s.lat,
            "lng": s.lng,
            "area_ha": s.area_ha,
            "temperature": s.temperature,
            "ndvi": s.ndvi,
            "planting_priority": s.planting_priority,
            "water_distance_m": s.water_distance_m,
            "geometry": json.loads(s.geometry) if s.geometry else None,
        }
        for s in sites
    ]

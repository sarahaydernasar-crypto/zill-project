from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from project.database import get_db
from project.models import AreaDB

router = APIRouter(
    prefix="/api/areas",
    tags=["Mobile App - Areas & Spatial Data"]
)

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
            "planting_priority": area.planting_priority
        })
    return result
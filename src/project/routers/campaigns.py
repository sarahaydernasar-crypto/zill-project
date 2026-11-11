from datetime import date
from typing import Literal, Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, Field, model_validator
from sqlalchemy.orm import Session

from project.auth import require_admin
from project.database import get_db
from project.models import CampaignDB, User
from project.points import CAMPAIGN_POINTS, award
from project.uploads import save_photo

router = APIRouter(prefix="/api/campaigns", tags=["Planting Campaigns"])


class CampaignFields(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    area_name: str = Field(min_length=1, max_length=200)
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    radius_m: float = Field(default=100, gt=0, le=2000)
    planted_on: date
    trees_planted: int = Field(gt=0)
    trees_alive: Optional[int] = Field(default=None, ge=0)
    tree_species: Optional[str] = Field(default=None, max_length=300)
    condition: Literal["healthy", "needs_care", "damaged", "unknown"] = "unknown"
    notes: Optional[str] = Field(default=None, max_length=2000)

    @model_validator(mode="after")
    def alive_not_more_than_planted(self):
        if self.trees_alive is not None and self.trees_alive > self.trees_planted:
            raise ValueError("عدد الأشجار الحية لا يمكن أن يتجاوز عدد المزروعة")
        return self


def _to_dict(c: CampaignDB) -> dict:
    return {
        "id": c.id,
        "name": c.name,
        "area_name": c.area_name,
        "lat": c.lat,
        "lng": c.lng,
        "radius_m": c.radius_m,
        "planted_on": c.planted_on.isoformat(),
        "trees_planted": c.trees_planted,
        "trees_alive": c.trees_alive,
        "tree_species": c.tree_species,
        "condition": c.condition,
        "notes": c.notes,
        "photo_before": c.photo_before,
        "photo_after": c.photo_after,
        "measurement": None if c.measured_at is None else {
            "period_before": c.period_before,
            "period_after": c.period_after,
            "ndvi_before": c.ndvi_before,
            "ndvi_after": c.ndvi_after,
            "temp_before": c.temp_before,
            "temp_after": c.temp_after,
            "green_ha_before": c.green_ha_before,
            "green_ha_after": c.green_ha_after,
            "ref_ndvi_before": c.ref_ndvi_before,
            "ref_ndvi_after": c.ref_ndvi_after,
            "ref_temp_before": c.ref_temp_before,
            "ref_temp_after": c.ref_temp_after,
            "measured_at": c.measured_at.isoformat(),
        },
    }


def _get_or_404(db: Session, campaign_id: int) -> CampaignDB:
    campaign = db.get(CampaignDB, campaign_id)
    if campaign is None:
        raise HTTPException(status_code=404, detail="الحملة غير موجودة")
    return campaign


@router.get("/")
def list_campaigns(db: Session = Depends(get_db)):
    campaigns = db.query(CampaignDB).order_by(CampaignDB.planted_on.desc()).all()
    return [_to_dict(c) for c in campaigns]


@router.post("/", status_code=201)
def create_campaign(data: CampaignFields, db: Session = Depends(get_db), _: str = Depends(require_admin)):
    campaign = CampaignDB(**data.model_dump())
    db.add(campaign)
    db.commit()
    return _to_dict(campaign)


@router.put("/{campaign_id}")
def update_campaign(
    campaign_id: int,
    data: CampaignFields,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin),
):
    campaign = _get_or_404(db, campaign_id)
    for field, value in data.model_dump().items():
        setattr(campaign, field, value)
    db.commit()
    return _to_dict(campaign)


@router.delete("/{campaign_id}", status_code=204)
def delete_campaign(campaign_id: int, db: Session = Depends(get_db), _: str = Depends(require_admin)):
    db.delete(_get_or_404(db, campaign_id))
    db.commit()


@router.post("/{campaign_id}/photo/{kind}")
async def upload_photo(
    campaign_id: int,
    kind: Literal["before", "after"],
    photo: UploadFile = File(...),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin),
):
    campaign = _get_or_404(db, campaign_id)
    setattr(campaign, f"photo_{kind}", await save_photo(photo, db))
    db.commit()
    return _to_dict(campaign)


class Participant(BaseModel):
    username: str = Field(min_length=1, max_length=30)


@router.post("/{campaign_id}/participants")
def add_participant(
    campaign_id: int,
    data: Participant,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin),
):
    """يمنح مشارك الحملة نقاطه مرة واحدة لكل حملة."""
    campaign = _get_or_404(db, campaign_id)
    user = db.query(User).filter(User.username == data.username.strip(), User.is_admin.is_(False)).first()
    if user is None:
        raise HTTPException(status_code=404, detail="لا يوجد مستخدم بهذا الاسم")
    award(db, user.id, CAMPAIGN_POINTS, f"المشاركة في حملة {campaign.name}", f"campaign:{campaign.id}:{user.id}")
    db.commit()
    return {"username": user.username}

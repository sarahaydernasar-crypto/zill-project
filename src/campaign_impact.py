"""يقيس من صور الأقمار الصناعية أثر كل حملة تشجير: قبل الزراعة مقابل آخر صيف متاح.

يقارن الموقع بحلقة محيطة به (500 متر) حتى لا يُنسب تغير الطقس بين السنتين إلى التشجير.
يحتاج إلى حساب Earth Engine:
uv run python src/campaign_impact.py
"""
import os
from datetime import date, datetime

import ee

from project.database import SessionLocal, ensure_schema
from project.models import CampaignDB

EE_PROJECT = os.getenv("EE_PROJECT", "gen-lang-client-0717475984")
GREEN_NDVI = 0.2  # نفس عتبة الغطاء النباتي الضعيف في التحليل
REFERENCE_RING_M = 500
MIN_MONTHS_AFTER_PLANTING = 12  # نمو الأشجار لا يظهر في الصور قبل ذلك


def summer_image(year, region):
    def prepare(image):
        qa = image.select("QA_PIXEL")
        clear = qa.bitwiseAnd(1 << 3).eq(0).And(qa.bitwiseAnd(1 << 4).eq(0))
        nir = image.select("SR_B5").multiply(0.0000275).add(-0.2)
        red = image.select("SR_B4").multiply(0.0000275).add(-0.2)
        ndvi = nir.subtract(red).divide(nir.add(red)).rename("ndvi")
        lst = image.select("ST_B10").multiply(0.00341802).add(149).subtract(273.15).rename("temp")
        return ndvi.addBands(lst).updateMask(clear)

    # Landsat 8 و9 معاً حتى تتوفر السنوات السابقة لإطلاق Landsat 9
    collection = (
        ee.ImageCollection("LANDSAT/LC08/C02/T1_L2")
        .merge(ee.ImageCollection("LANDSAT/LC09/C02/T1_L2"))
        .filterBounds(region)
        .filterDate(f"{year}-06-01", f"{year}-09-01")
        .map(prepare)
    )
    return collection.median()


def mean_values(image, region):
    return image.reduceRegion(ee.Reducer.mean(), region, 30, maxPixels=1e8).getInfo()


def green_hectares(image, region):
    green = image.select("ndvi").gte(GREEN_NDVI).multiply(ee.Image.pixelArea()).divide(10000)
    return green.reduceRegion(ee.Reducer.sum(), region, 30, maxPixels=1e8).getInfo()["ndvi"]


def measure(campaign, today):
    planted = campaign.planted_on
    months = (today.year - planted.year) * 12 + today.month - planted.month
    if months < MIN_MONTHS_AFTER_PLANTING:
        print(f"⏳ {campaign.name}: مرت {months} شهراً فقط، تم تجاوزها.")
        return

    # آخر صيف مكتمل قبل الزراعة
    year_before = planted.year if planted.month >= 9 else planted.year - 1
    # آخر صيف مكتمل
    year_after = today.year if today.month >= 9 else today.year - 1
    site = ee.Geometry.Point([campaign.lng, campaign.lat]).buffer(campaign.radius_m)
    ring = (
        ee.Geometry.Point([campaign.lng, campaign.lat])
        .buffer(campaign.radius_m + REFERENCE_RING_M)
        .difference(site, 1)
    )
    before, after = summer_image(year_before, site.union(ring, 1)), summer_image(year_after, site.union(ring, 1))
    site_before, site_after = mean_values(before, site), mean_values(after, site)
    ref_before, ref_after = mean_values(before, ring), mean_values(after, ring)
    if site_before["ndvi"] is None or site_after["ndvi"] is None:
        print(f"⚠️ {campaign.name}: لا توجد صور صافية كافية، تم تجاوزها.")
        return

    campaign.period_before = f"صيف {year_before}"
    campaign.period_after = f"صيف {year_after}"
    campaign.ndvi_before = round(site_before["ndvi"], 3)
    campaign.ndvi_after = round(site_after["ndvi"], 3)
    campaign.temp_before = round(site_before["temp"], 1)
    campaign.temp_after = round(site_after["temp"], 1)
    campaign.green_ha_before = round(green_hectares(before, site), 2)
    campaign.green_ha_after = round(green_hectares(after, site), 2)
    campaign.ref_ndvi_before = round(ref_before["ndvi"], 3)
    campaign.ref_ndvi_after = round(ref_after["ndvi"], 3)
    campaign.ref_temp_before = round(ref_before["temp"], 1)
    campaign.ref_temp_after = round(ref_after["temp"], 1)
    campaign.measured_at = datetime.utcnow()
    print(f"📈 {campaign.name}: NDVI {campaign.ndvi_before} ← {campaign.ndvi_after}")


def main():
    ee.Initialize(project=EE_PROJECT)
    ensure_schema()
    db = SessionLocal()
    try:
        campaigns = db.query(CampaignDB).all()
        if not campaigns:
            print("لا توجد حملات مسجلة بعد.")
        for campaign in campaigns:
            measure(campaign, date.today())
        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    main()

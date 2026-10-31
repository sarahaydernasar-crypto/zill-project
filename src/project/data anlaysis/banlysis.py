import ee
import geemap

ee.Initialize(project="gen-lang-client-0717475984")

boundaries = ee.FeatureCollection("FAO/GAUL/2025/level1")

baghdad = boundaries.filter(
    ee.Filter.eq("GAUL1_NAME", "Baghdad")
)

#print("Baghdad boundary count:", baghdad.size().getInfo())

images = (
    ee.ImageCollection("LANDSAT/LC09/C02/T1_L2")
    .filterBounds(baghdad.geometry())
    .filterDate("2026-06-01", "2026-09-01")
)

images = images.filter(ee.Filter.eq("PROCESSING_LEVEL", "L2SP"))


#print("images with L2SP processing level:", images.size().getInfo())

def mask_clouds(image):
    qa = image.select("QA_PIXEL")

    fill = 1 << 0
    dilated_cloud = 1 << 1
    cirrus = 1 << 2
    cloud = 1 << 3
    cloud_shadow = 1 << 4
    snow = 1 << 5

    mask = (
    qa.bitwiseAnd(fill).eq(0)
    .And(qa.bitwiseAnd(dilated_cloud).eq(0))
    .And(qa.bitwiseAnd(cirrus).eq(0))
    .And(qa.bitwiseAnd(cloud).eq(0))
    .And(qa.bitwiseAnd(cloud_shadow).eq(0))
    .And(qa.bitwiseAnd(snow).eq(0))
    )

    return image.updateMask(mask)


clean_images = images.map(mask_clouds)

#print("Images after cloud masking:", clean_images.size().getInfo())

def calculate_lst(image):
    temperature = image.select("ST_B10")

    lst_celsius = (
        temperature.multiply(0.00341802)
        .add(149.0)
        .subtract(273.15)
    )

    return image.addBands(
        lst_celsius.rename("LST_C")
    )

lst_images = clean_images.map(calculate_lst)

#print("Images with calculated LST:", lst_images.size().getInfo())

def get_temperature_stats(image):
    stats = image.select("LST_C").reduceRegion(
        reducer=ee.Reducer.percentile([5, 50, 95]).combine(
            reducer2=ee.Reducer.minMax(),
            sharedInputs=True
        ),
        geometry=baghdad.geometry(),
        scale=100,
        maxPixels=1e9
    )

    return ee.Feature(None, stats).set(
        "image_date",
        image.date().format("YYYY-MM-dd")
    )

temperature_stats = ee.FeatureCollection(
    lst_images.map(get_temperature_stats)
)

# print("Temperature statistics for all images:")
# print(temperature_stats.getInfo())

lst_projection = lst_images.first().select("LST_C").projection()
median_lst = (
    lst_images.select("LST_C")
    .median()
    .setDefaultProjection(lst_projection)
)

median_stats = median_lst.reduceRegion(
    reducer=ee.Reducer.percentile([5, 50, 95]).combine(
        reducer2=ee.Reducer.minMax(),
        sharedInputs=True
    ),
    geometry=baghdad.geometry(),
    scale=100,
    maxPixels=1e9
)

# print("Baghdad median LST statistics:")
# print(median_stats.getInfo())

heat_zones = (
    median_lst.select("LST_C").multiply(0)
    .where(median_lst.select("LST_C").gt(40), 1)
    .where(median_lst.select("LST_C").gt(50), 2)
    .updateMask(median_lst.select("LST_C").mask())
    .rename("heat_zone")
    .clip(baghdad.geometry())
)

# print("Heat zone classes: 0=cooler, 1=moderate, 2=hotter")

def calculate_ndvi(image):
    nir = image.select("SR_B5").multiply(0.0000275).add(-0.2)
    red = image.select("SR_B4").multiply(0.0000275).add(-0.2)

    ndvi = nir.subtract(red).divide(
        nir.add(red)
    ).rename("NDVI")

    return image.addBands(ndvi)

ndvi_images = images.map(mask_clouds).map(calculate_ndvi)

median_ndvi = ndvi_images.select("NDVI").median()

hot_areas = median_lst.select("LST_C").gte(45)
low_vegetation = median_ndvi.select("NDVI").lt(0.2)

land_cover = (
    ee.ImageCollection("GOOGLE/DYNAMICWORLD/V1")
    .filterBounds(baghdad.geometry())
    .filterDate("2026-06-01", "2026-09-01")
)
built_up = land_cover.select("label").mode().eq(6)

surface_water = (
    ee.Image("JRC/GSW1_4/GlobalSurfaceWater")
    .select("occurrence")
    .unmask(0)
    .gte(25)
)
distance_to_water = (
    surface_water.fastDistanceTransform(256, "pixels", "squared_euclidean")
    .sqrt()
    .multiply(30)
)
water_suitability = distance_to_water.multiply(-1).divide(2000).add(1).clamp(0, 1)

soil_water_capacity = (
    ee.Image("OpenLandMap/SOL/SOL_WATERCONTENT-33KPA_USDA-4B1C_M/v01")
    .select("b30")
    .divide(30)
    .clamp(0, 1)
)

heat_need = (
    median_lst.select("LST_C")
    .subtract(40)
    .divide(20)
    .clamp(0, 1)
)

planting_priority = (
    heat_need
    .multiply(water_suitability.add(soil_water_capacity).divide(2))
    .multiply(100)
    .updateMask(hot_areas)
    .updateMask(low_vegetation)
    .updateMask(built_up.Not())
    .selfMask()
    .rename("planting_priority")
    .clip(baghdad.geometry())
)

Map = geemap.Map(center=[33.3152, 44.3661], zoom=9)

lst_baghdad = median_lst.clip(baghdad.geometry())
ndvi_baghdad = median_ndvi.clip(baghdad.geometry())

Map.addLayer(
    heat_zones.clip(baghdad.geometry()),
    {
        "min": 0,
        "max": 2,
        "palette": ["4B91C7", "E8B44D", "D9534F"]
    },
    "Baghdad Heat Zones"
)

Map.addLayer(
    ndvi_baghdad,
    {
        "min": -0.2,
        "max": 0.6,
        "palette": ["8C510A", "F6E8C3", "A6DBA0", "01665E"]
    },
    "Baghdad NDVI"
)

Map.addLayer(
    planting_priority,
    {"min": 0, "max": 100, "palette": ["FCE4EC", "F06292", "AD1457"]},
    "Planting Priority"
)

Map.addLayer(
    baghdad.style(
        color="FFFFFF",
        fillColor="00000000",
        width=2
    ),
    {},
    "Baghdad Boundary"
)

Map.centerObject(baghdad, 9)
Map.to_html("baghdad_heat_and_ndvi.html")

export_folder = "Baghdad_Project_Exports"
export_region = baghdad.geometry()

landsat_analysis = (
    median_lst.select("LST_C")
    .addBands(median_ndvi.select("NDVI"))
    .addBands(heat_zones)
    .addBands(planting_priority)
    .addBands(heat_need.rename("heat_need"))
    .addBands(hot_areas.rename("hot_area_45plus"))
    .addBands(low_vegetation.rename("low_vegetation"))
    .addBands(built_up.rename("built_up"))
    .clip(export_region)
    .toFloat()
)

landsat_export = ee.batch.Export.image.toDrive(
    image=landsat_analysis,
    description="Baghdad_LST_NDVI_HeatZones_PlantingPriority_BuiltUp",
    folder=export_folder,
    fileNamePrefix="Baghdad_LST_NDVI_HeatZones_PlantingPriority_BuiltUp",
    region=export_region,
    scale=30,
    maxPixels=1e13,
    fileFormat="GeoTIFF",
)
landsat_export.start()

water_export = ee.batch.Export.image.toDrive(
    image=water_suitability.rename("water_suitability").clip(export_region),
    description="Baghdad_Water_Suitability",
    folder=export_folder,
    fileNamePrefix="Baghdad_Water_Suitability",
    region=export_region,
    scale=30,
    maxPixels=1e13,
    fileFormat="GeoTIFF",
)
water_export.start()

soil_export = ee.batch.Export.image.toDrive(
    image=soil_water_capacity.rename("soil_water_capacity").clip(export_region),
    description="Baghdad_Soil_Water_Capacity",
    folder=export_folder,
    fileNamePrefix="Baghdad_Soil_Water_Capacity",
    region=export_region,
    scale=250,
    maxPixels=1e13,
    fileFormat="GeoTIFF",
)
soil_export.start()

median_stats_table = ee.FeatureCollection([ee.Feature(None, median_stats)])
stats_export = ee.batch.Export.table.toDrive(
    collection=temperature_stats,
    description="Baghdad_PerImage_Temperature_Statistics",
    folder=export_folder,
    fileNamePrefix="Baghdad_PerImage_Temperature_Statistics",
    fileFormat="CSV",
)
stats_export.start()

median_stats_export = ee.batch.Export.table.toDrive(
    collection=median_stats_table,
    description="Baghdad_Median_Temperature_Statistics",
    folder=export_folder,
    fileNamePrefix="Baghdad_Median_Temperature_Statistics",
    fileFormat="CSV",
)
median_stats_export.start()

boundary_export = ee.batch.Export.table.toDrive(
    collection=baghdad,
    description="Baghdad_Boundary",
    folder=export_folder,
    fileNamePrefix="Baghdad_Boundary",
    fileFormat="GeoJSON",
)
boundary_export.start()

#print("Export tasks started. Check the Earth Engine Tasks page for progress.")
#print("Boundary and image search completed!")
import json
from pathlib import Path

# ===== تصدير نتائج حقيقية لكل قضاء من أقضية بغداد =====
# كل الأرقام تُحسب من الصور الفضائية؛ لا توجد قيم افتراضية.
districts = ee.FeatureCollection("FAO/GAUL/2025/level2").filter(
    ee.Filter.eq("GAUL1_NAME", "Baghdad")
)

# أسماء الأقضية بالعربية (إن لم يوجد الاسم هنا يُستخدم الاسم الإنجليزي من GAUL)
DISTRICT_NAMES_AR = {
    "karkh": "الكرخ",
    "rusafa": "الرصافة",
    "resafa": "الرصافة",
    "adhamiya": "الأعظمية",
    "adhamiyah": "الأعظمية",
    "kadhimiya": "الكاظمية",
    "kadhimiyah": "الكاظمية",
    "sadr": "مدينة الصدر",
    "thawra": "مدينة الصدر",
    "mahmudiya": "المحمودية",
    "mahmoudiya": "المحمودية",
    "abu ghraib": "أبو غريب",
    "tarmiya": "الطارمية",
    "taji": "التاجي",
    "madain": "المدائن",
    "mada'in": "المدائن",
}

def arabic_name(name_en):
    key = (name_en or "").lower()
    for k, v in DISTRICT_NAMES_AR.items():
        if k in key:
            return v
    return name_en

def classify(temp):
    # نفس عتبات heat_zones أعلاه
    if temp > 50:
        return "Hotter"
    if temp > 40:
        return "Moderate"
    return "Cooler"

stats_image = (
    median_lst.select("LST_C").rename("temperature")
    .addBands(median_ndvi.select("NDVI").rename("ndvi"))
    .addBands(planting_priority.rename("planting_priority"))
)

district_stats = stats_image.reduceRegions(
    collection=districts,
    reducer=ee.Reducer.mean(),
    scale=100,
).map(lambda f: f.setGeometry(f.geometry().simplify(200)))

final_output = []
for feat in district_stats.getInfo()["features"]:
    props = feat["properties"]
    temp = props.get("temperature")
    ndvi = props.get("ndvi")
    if temp is None or ndvi is None:
        print(f"⚠️ لا توجد بيانات كافية لـ {props.get('GAUL2_NAME')}، تم تجاوزه.")
        continue
    final_output.append({
        "name": arabic_name(props.get("GAUL2_NAME")),
        "temperature": round(temp, 1),
        "classification": classify(temp),
        "ndvi": round(ndvi, 3),
        # متوسط درجة الأولوية للبكسلات المرشحة فقط (حارة + نبات ضعيف + غير مبنية)؛ 0 إن لم يوجد أي بكسل مرشح
        "planting_priority": round(props.get("planting_priority") or 0, 1),
        "geometry": feat["geometry"],
    })

if not final_output:
    raise RuntimeError("لم يتم حساب أي قضاء. تحقق من اسم مجموعة GAUL والحقول GAUL1_NAME/GAUL2_NAME.")

output_file = Path(__file__).resolve().parents[3] / "baghdad_results.json"
with open(output_file, "w", encoding="utf-8") as f:
    json.dump(final_output, f, ensure_ascii=False, indent=4)

print(f"✨ تم تصدير {len(final_output)} قضاء إلى {output_file}")

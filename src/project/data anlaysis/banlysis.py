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

# رسم خريطة HTML يحتاج صلاحية earthengine.maps.create (دور Writer)؛
# دور Viewer يكفي لحساب الأرقام، فلا نوقف التحليل إذا لم تتوفر هذه الصلاحية
try:
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
except ee.EEException as e:
    print(f"⚠️ لم يتم تحديث خريطة HTML: {e}")

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
# التصدير إلى Drive يحتاج صلاحية earthengine.exports.create (دور Writer)
try:
    landsat_export.start()
except ee.EEException as e:
    print(f"⚠️ لم يبدأ التصدير (landsat_export): {e}")

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
# التصدير إلى Drive يحتاج صلاحية earthengine.exports.create (دور Writer)
try:
    water_export.start()
except ee.EEException as e:
    print(f"⚠️ لم يبدأ التصدير (water_export): {e}")

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
# التصدير إلى Drive يحتاج صلاحية earthengine.exports.create (دور Writer)
try:
    soil_export.start()
except ee.EEException as e:
    print(f"⚠️ لم يبدأ التصدير (soil_export): {e}")

median_stats_table = ee.FeatureCollection([ee.Feature(None, median_stats)])
stats_export = ee.batch.Export.table.toDrive(
    collection=temperature_stats,
    description="Baghdad_PerImage_Temperature_Statistics",
    folder=export_folder,
    fileNamePrefix="Baghdad_PerImage_Temperature_Statistics",
    fileFormat="CSV",
)
# التصدير إلى Drive يحتاج صلاحية earthengine.exports.create (دور Writer)
try:
    stats_export.start()
except ee.EEException as e:
    print(f"⚠️ لم يبدأ التصدير (stats_export): {e}")

median_stats_export = ee.batch.Export.table.toDrive(
    collection=median_stats_table,
    description="Baghdad_Median_Temperature_Statistics",
    folder=export_folder,
    fileNamePrefix="Baghdad_Median_Temperature_Statistics",
    fileFormat="CSV",
)
# التصدير إلى Drive يحتاج صلاحية earthengine.exports.create (دور Writer)
try:
    median_stats_export.start()
except ee.EEException as e:
    print(f"⚠️ لم يبدأ التصدير (median_stats_export): {e}")

boundary_export = ee.batch.Export.table.toDrive(
    collection=baghdad,
    description="Baghdad_Boundary",
    folder=export_folder,
    fileNamePrefix="Baghdad_Boundary",
    fileFormat="GeoJSON",
)
# التصدير إلى Drive يحتاج صلاحية earthengine.exports.create (دور Writer)
try:
    boundary_export.start()
except ee.EEException as e:
    print(f"⚠️ لم يبدأ التصدير (boundary_export): {e}")

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
    "kadhmiyah": "الكاظمية",
    "risafa": "الرصافة",
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
    # خصائص الموقع المستخدمة في اقتراح أنواع الأشجار
    .addBands(built_up.toFloat().rename("built_up_ratio"))
    .addBands(distance_to_water.rename("water_distance_m"))
    .addBands(soil_water_capacity.rename("soil_water"))
)

district_stats = stats_image.reduceRegions(
    collection=districts,
    reducer=ee.Reducer.mean(),
    # يجب أن تساوي 30: distance_to_water يحوّل البكسل إلى أمتار بافتراض 30 متراً
    scale=30,
    tileScale=4,
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
        "built_up_ratio": round(props.get("built_up_ratio") or 0, 3),
        "water_distance_m": round(props.get("water_distance_m") or 0),
        "soil_water": round(props.get("soil_water") or 0, 3),
        "geometry": feat["geometry"],
    })

if not final_output:
    raise RuntimeError("لم يتم حساب أي قضاء. تحقق من اسم مجموعة GAUL والحقول GAUL1_NAME/GAUL2_NAME.")

output_file = Path(__file__).resolve().parents[3] / "baghdad_results.json"
with open(output_file, "w", encoding="utf-8") as f:
    json.dump(final_output, f, ensure_ascii=False, indent=4)

print(f"✨ تم تصدير {len(final_output)} قضاء إلى {output_file}")


# ===== مواقع تشجير مقترحة داخل كل قضاء =====
# أراضٍ مكشوفة وغير مبنية وسط العمران، حارة وضعيفة النبات. هي مواقع "محتملة":
# الصور لا تكشف الملكية أو الاستخدام، فيجب التحقق منها ميدانياً.
import math
import time
import urllib.parse
import urllib.request
from shapely import STRtree
from shapely.geometry import LineString, Polygon, shape

SITES_PER_DISTRICT = 8
MIN_SITE_HA, MAX_SITE_HA = 0.5, 50
MIN_COMPACTNESS = 0.2  # يستبعد الأشرطة الطويلة مثل جوانب الطرق
MAX_EXCLUDED_OVERLAP = 0.1
HTTP_HEADERS = {"User-Agent": "zill-project-analysis/1.0 (Baghdad urban heat study)"}

# Dynamic World: 2 عشب، 5 شجيرات متناثرة، 7 أرض جرداء
land_label = land_cover.select("label").mode()
open_land = land_label.eq(2).Or(land_label.eq(5)).Or(land_label.eq(7))
# وسط العمران: ربع المساحة على الأقل مبني ضمن 300 متر
urban_context = built_up.unmask(0).toFloat().focalMean(300, "circle", "meters").gte(0.25)
# استبعاد ما يُحتمل أنه مبني: احتمال البناء عبر الصيف، وما يبعد أقل من 30 متراً عن مبنى
low_built_probability = land_cover.select("built").mean().lt(0.2)
away_from_buildings = built_up.unmask(0).focalMax(30, "circle", "meters").Not()
site_mask = (
    open_land.And(urban_context).And(low_built_probability).And(away_from_buildings)
    .And(planting_priority.mask())
)

def overpass(query):
    """طلب من Overpass؛ الخدمة العامة قد تكون مزدحمة، فنعيد المحاولة على خادمين."""
    data = urllib.parse.urlencode({"data": query}).encode()
    servers = ("https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter")
    for attempt, url in enumerate(servers * 3):
        if attempt:
            time.sleep(30)
        try:
            req = urllib.request.Request(url, data=data, headers=HTTP_HEADERS)
            with urllib.request.urlopen(req, timeout=180) as r:
                return json.load(r)["elements"]
        except Exception as e:
            print(f"⚠️ تعذر الاتصال بـ {url}: {e}")
    raise RuntimeError("تعذر الاتصال بخدمة Overpass.")

def fetch_excluded_areas():
    """مناطق لا تصلح للتشجير من OpenStreetMap: مطارات ومقابر ومواقع عسكرية وصناعية ومحطات وطرق رئيسية."""
    ring = baghdad.geometry().bounds().getInfo()["coordinates"][0]
    west, south, east, north = ring[0][0], ring[0][1], ring[2][0], ring[2][1]
    bbox = f"{south},{west},{north},{east}"
    query = f"""[out:json][timeout:120];
    (way["landuse"~"cemetery|military|railway|industrial|landfill|quarry"]({bbox});
     relation["landuse"~"cemetery|military|industrial"]({bbox});
     way["man_made"~"wastewater_plant|water_works|works"]({bbox});
     way["power"~"plant|substation"]({bbox});
     way["highway"~"motorway|trunk|primary"]({bbox});
     way["amenity"="grave_yard"]({bbox});
     way["aeroway"="aerodrome"]({bbox});
     relation["aeroway"="aerodrome"]({bbox});
     way["military"]({bbox}););
    out geom;"""
    elements = overpass(query)

    shapes = []
    for el in elements:
        ways = [el] if el["type"] == "way" else [m for m in el.get("members", []) if m.get("role") == "outer"]
        for way in ways:
            coords = [(p["lon"], p["lat"]) for p in way.get("geometry", [])]
            if len(coords) >= 4 and coords[0] == coords[-1]:
                shapes.append(Polygon(coords).buffer(0))
            elif len(coords) >= 2:
                shapes.append(LineString(coords).buffer(0.0005))  # نحو 50 متراً حول السكك والحدود
    return shapes

def place_name(lat, lon):
    """اسم أقرب حي أو شارع من OpenStreetMap؛ بحد طلب واحد في الثانية حسب سياسة الخدمة."""
    url = ("https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=16&accept-language=ar"
           f"&lat={lat}&lon={lon}")
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=HTTP_HEADERS), timeout=30) as r:
            address = json.load(r).get("address", {})
    except Exception:
        return None
    finally:
        time.sleep(1.1)
    for key in ("neighbourhood", "suburb", "quarter", "road", "city_district"):
        if address.get(key):
            return address[key]
    return None

excluded_areas = fetch_excluded_areas()
excluded_tree = STRtree(excluded_areas)
print(f"🚫 مناطق مستبعدة من OpenStreetMap: {len(excluded_areas)}")

site_stats_image = stats_image.select(["temperature", "ndvi", "planting_priority", "water_distance_m"])
final_sites = []

for district in districts.getInfo()["features"]:
    district_en = district["properties"]["GAUL2_NAME"]
    region = ee.Feature(district).geometry()
    vectors = (
        site_mask.selfMask().toInt().rename("site").clip(region)
        .reduceToVectors(
            geometry=region, scale=30, geometryType="polygon", eightConnected=True,
            labelProperty="site", maxPixels=1e10, tileScale=4,
        )
        .map(lambda f: f.set("area_ha", f.geometry().area(10).divide(10000)))
        .filter(ee.Filter.rangeContains("area_ha", MIN_SITE_HA, MAX_SITE_HA))
        .limit(150, "area_ha", False)
    )
    candidates = site_stats_image.reduceRegions(
        collection=vectors, reducer=ee.Reducer.mean(), scale=30, tileScale=4,
    ).getInfo()["features"]

    kept = []
    for feat in sorted(candidates, key=lambda f: f["properties"].get("planting_priority") or 0, reverse=True):
        geom = shape(feat["geometry"]).buffer(0)
        if geom.is_empty or feat["properties"].get("planting_priority") is None:
            continue
        compactness = 4 * math.pi * geom.area / (geom.length ** 2)
        nearby = excluded_tree.query(geom, predicate="intersects")
        overlap = sum(geom.intersection(excluded_areas[i]).area for i in nearby) / geom.area
        if compactness < MIN_COMPACTNESS or overlap > MAX_EXCLUDED_OVERLAP:
            continue
        kept.append((feat["properties"], geom))
        if len(kept) == SITES_PER_DISTRICT:
            break

    district_ar = arabic_name(district_en)
    print(f"📍 {district_ar}: {len(candidates)} مرشحة، أُبقي {len(kept)}")
    for props, geom in kept:
        center = geom.representative_point()
        final_sites.append({
            "district": district_ar,
            "place": place_name(round(center.y, 5), round(center.x, 5)),
            "lat": round(center.y, 5),
            "lng": round(center.x, 5),
            "area_ha": round(props["area_ha"], 1),
            "temperature": round(props["temperature"], 1),
            "ndvi": round(props["ndvi"], 3),
            "planting_priority": round(props["planting_priority"], 1),
            "water_distance_m": round(props["water_distance_m"]),
            "geometry": json.loads(json.dumps(geom.simplify(0.0001).__geo_interface__)),
        })

sites_file = Path(__file__).resolve().parents[3] / "baghdad_sites.json"
with open(sites_file, "w", encoding="utf-8") as f:
    json.dump(final_sites, f, ensure_ascii=False, indent=2)

print(f"🌳 تم تصدير {len(final_sites)} موقعاً إلى {sites_file}")


# ===== المناطق داخل كل قضاء (أحياء أو نواحٍ) =====
# الحدود من OpenStreetMap، وتُحسب لها الأرقام نفسها المحسوبة للأقضية.
from shapely.geometry import mapping
from shapely.ops import polygonize, unary_union

MIN_NEIGHBOURHOOD_COVERAGE = 0.5  # تُستخدم الأحياء إذا غطت نصف القضاء، وإلا فالنواحي
MIN_SUB_AREA_DEG2 = 1e-5  # نحو 10 هكتارات؛ يستبعد البقايا الصغيرة بعد القص


def admin_units():
    ring = baghdad.geometry().bounds().getInfo()["coordinates"][0]
    bbox = f"{ring[0][1]},{ring[0][0]},{ring[2][1]},{ring[2][0]}"
    elements = overpass(f"""[out:json][timeout:150];
    relation["boundary"="administrative"]["admin_level"~"^(7|8)$"]({bbox});
    out geom;""")
    units = []
    for el in elements:
        tags = el.get("tags", {})
        name = tags.get("name:ar") or tags.get("name")
        lines = [
            LineString([(p["lon"], p["lat"]) for p in m["geometry"]])
            for m in el.get("members", [])
            if m.get("type") == "way" and m.get("role") == "outer" and len(m.get("geometry", [])) >= 2
        ]
        polygons = list(polygonize(unary_union(lines))) if lines else []
        if not name or not polygons:
            continue
        # توحيد الحروف الفارسية التي ترد في بعض الأسماء
        name = name.replace("ک", "ك").replace("ی", "ي")
        units.append({"name": name, "level": tags["admin_level"], "geom": unary_union(polygons).buffer(0)})
    return units


def units_for_district(units, district_geom):
    inside = [u for u in units if district_geom.contains(u["geom"].representative_point())]
    neighbourhoods = [u for u in inside if u["level"] == "8"]
    covered = sum(u["geom"].intersection(district_geom).area for u in neighbourhoods)
    chosen = neighbourhoods if covered >= MIN_NEIGHBOURHOOD_COVERAGE * district_geom.area else \
        [u for u in inside if u["level"] == "7"]
    result = []
    for u in chosen:
        clipped = u["geom"].intersection(district_geom)
        if clipped.area >= MIN_SUB_AREA_DEG2:
            result.append({**u, "geom": clipped.simplify(0.0003).buffer(0)})
    return result


admin = admin_units()
print(f"🏘️ وحدات إدارية من OpenStreetMap: {len(admin)}")

final_sub_areas = []
for district in districts.getInfo()["features"]:
    district_ar = arabic_name(district["properties"]["GAUL2_NAME"])
    units = units_for_district(admin, shape(district["geometry"]).buffer(0))
    if not units:
        print(f"⚠️ {district_ar}: لا توجد مناطق داخلية.")
        continue
    collection = ee.FeatureCollection([
        ee.Feature(ee.Geometry(mapping(u["geom"])), {"unit": i}) for i, u in enumerate(units)
    ])
    stats = stats_image.reduceRegions(
        collection=collection, reducer=ee.Reducer.mean(), scale=30, tileScale=4,
    ).map(lambda f: f.setGeometry(None)).getInfo()["features"]

    kept = 0
    for feat in stats:
        props = feat["properties"]
        unit = units[props["unit"]]
        if props.get("temperature") is None or props.get("ndvi") is None:
            continue
        final_sub_areas.append({
            "district": district_ar,
            "name": unit["name"],
            "level": "حي" if unit["level"] == "8" else "ناحية",
            "temperature": round(props["temperature"], 1),
            "classification": classify(props["temperature"]),
            "ndvi": round(props["ndvi"], 3),
            "planting_priority": round(props.get("planting_priority") or 0, 1),
            "built_up_ratio": round(props.get("built_up_ratio") or 0, 3),
            "water_distance_m": round(props.get("water_distance_m") or 0),
            "soil_water": round(props.get("soil_water") or 0, 3),
            "geometry": mapping(unit["geom"]),
        })
        kept += 1
    print(f"📍 {district_ar}: {kept} منطقة ({'أحياء' if units[0]['level'] == '8' else 'نواحٍ'})")

sub_areas_file = Path(__file__).resolve().parents[3] / "baghdad_sub_areas.json"
with open(sub_areas_file, "w", encoding="utf-8") as f:
    json.dump(final_sub_areas, f, ensure_ascii=False, indent=2)

print(f"🗺️ تم تصدير {len(final_sub_areas)} منطقة إلى {sub_areas_file}")

# Baghdad Heat, NDVI, and Planting Priority

This project analyzes Landsat 9 imagery over Baghdad for summer 2026. It produces land surface temperature (LST), NDVI, heat zones, and a planting priority score.

## Method

- Heat zones use fixed thresholds: below 40°C, 40–50°C, and above 50°C.
- Planting priority considers areas with LST of 45°C or higher and NDVI below 0.2.
- Areas classified as built-up are excluded.
- The 0–100 planting score combines heat need, proximity to historical surface water, and soil water-holding capacity.

The planting score is a preliminary suitability score, not a measured probability of planting success. Water proximity is a proxy for water access, and soil data is available at a coarser resolution.

## Project data

[Open the exported data in Google Drive](https://drive.google.com/drive/folders/1Sb7gfRDrMvLVhRavHQs6-6zvPR6WgSTd?usp=drive_link)

## Data sources

- Landsat 9 Collection 2 Level 2
- Dynamic World land-cover classification
- JRC Global Surface Water
- OpenLandMap soil water content

## Requirements

- Python 3.11 or later
- Google Earth Engine access and authentication
- `earthengine-api`
- `geemap`
- `uv`

## Run

From the `zill-project` directory:

```bash
uv sync
cp .env.example .env                                   # then put the real DATABASE_URL in .env
uv run python "src/project/data anlaysis/banlysis.py"  # 1. analysis -> baghdad_results.json (per district)
uv run python src/ingest_data.py                       # 2. load results into the database
uv run uvicorn project.main:app --reload               # 3. API on http://127.0.0.1:8000
```

- Web interface: http://127.0.0.1:8000/app/
- Flutter app: see `zill_app/README.md`

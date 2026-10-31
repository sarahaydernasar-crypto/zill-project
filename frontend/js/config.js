// إعدادات الواجهة — عدّل هنا فقط عند تغيير مكان الـ Backend
window.ZILL_CONFIG = {
  // إذا كانت الواجهة تُخدَّم من FastAPI نفسه (/app) نترك العنوان فارغاً،
  // وإلا نتصل بالـ Backend المحلي على المنفذ 8000
  API_BASE: location.port === "8000" ? "" : "http://127.0.0.1:8000",
  AREAS_ENDPOINT: "/api/areas/",
  ANALYSIS_MAP_PATH: "/map",

  // مركز بغداد كما في سكربت التحليل
  CITY_CENTER: [33.3152, 44.3661],
  CITY_ZOOM: 10,

  // عتبات الحرارة (°م) — مطابقة لطريقة التحليل في README
  HEAT_THRESHOLDS: { extreme: 50, hot: 45, warm: 40 },
  // شروط الترشيح للتشجير
  PLANTING_MIN_TEMP: 45,
  PLANTING_MAX_NDVI: 0.2,
};

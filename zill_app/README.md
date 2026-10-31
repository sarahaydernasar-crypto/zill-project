# ظِلّ — تطبيق Flutter

تطبيق المواطن وموظف البلدية: خريطة حرارة بغداد وتوصيات التشجير.

## الشاشات

| الشاشة | الملف |
|---|---|
| الرئيسية | `lib/screens/home_screen.dart` |
| لوحة المعلومات والخريطة | `lib/screens/map_screen.dart` |
| تفاصيل المنطقة | `lib/widgets/area_details.dart` (لوحة جانبية على الشاشات الكبيرة، ونافذة سفلية على الموبايل) |
| توصيات التشجير | `lib/screens/recommendations_screen.dart` |
| عن المشروع | `lib/screens/about_screen.dart` |

- البيانات تأتي من `GET /api/areas/` (الملف `lib/services/areas_store.dart`). لا توجد أرقام افتراضية داخل التطبيق.
- الألوان وعتبات الحرارة موجودة في `lib/theme.dart` و`lib/config.dart`.
- إذا أرسل الـ API لكل منطقة حقل `geometry` (بصيغة GeoJSON) تُرسم حدودها على الخريطة. وإذا أرسل `lat`/`lng` تظهر المنطقة كنقطة.

## التشغيل

1. شغّل الـ Backend من مجلد `zill-project`:
   ```bash
  uv run uvicorn project.main:app --host 0.0.0.0 --port 8000
   ```
2. شغّل التطبيق:
   ```bash
   cd zill_app
   flutter pub get
   flutter run -d chrome          # في المتصفح
   flutter run                    # على محاكي أندرويد (يتصل تلقائياً بـ 10.0.2.2:8000)
   ```
3. على هاتف حقيقي، مرّر عنوان IP الخاص بالحاسوب:
   ```bash
   flutter run --dart-define=API_BASE=http://192.168.1.10:8000
   ```

على الويب يمكن فتح صفحة معينة مباشرة من الرابط، مثلاً `?tab=map` أو `?tab=recommendations` أو `?tab=about`.

## الاختبارات
```bash
flutter analyze
flutter test
```

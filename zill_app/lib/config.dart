import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// إعدادات التطبيق — عدّل هنا فقط عند تغيير مكان الـ Backend.
class AppConfig {
  /// يمكن تمرير عنوان الخادم عند التشغيل:
  /// flutter run --dart-define=API_BASE=http://192.168.1.10:8000
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE');

  static String get apiBase {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    // محاكي أندرويد يصل إلى جهاز الحاسوب عبر 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const String areasEndpoint = '/api/areas/';
  static const String analysisMapPath = '/map';

  /// مركز بغداد كما في سكربت التحليل
  static const LatLng cityCenter = LatLng(33.3152, 44.3661);
  static const double cityZoom = 10;

  /// عتبات الحرارة (°م) — مطابقة لطريقة التحليل في README
  static const double extremeTemp = 50;
  static const double hotTemp = 45;
  static const double warmTemp = 40;

  /// شروط الترشيح للتشجير
  static const double plantingMinTemp = 45;
  static const double plantingMaxNdvi = 0.2;
}

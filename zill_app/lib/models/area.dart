import 'dart:ui';

import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../theme.dart';

/// مستوى الحرارة المستخدم في التلوين ومفتاح الألوان
enum HeatLevel {
  extreme('أعلى حرارة', ZillColors.heatExtreme),
  hot('حارة', ZillColors.heatHot),
  warm('متوسطة', ZillColors.heatWarm),
  cool('أقل حرارة', ZillColors.heatCool);

  const HeatLevel(this.label, this.color);
  final String label;
  final Color color;

  String get range => switch (this) {
        HeatLevel.extreme => '> ${deg(AppConfig.extremeTemp, 0)}',
        HeatLevel.hot => _range(AppConfig.hotTemp, AppConfig.extremeTemp),
        HeatLevel.warm => _range(AppConfig.warmTemp, AppConfig.hotTemp),
        HeatLevel.cool => '< ${deg(AppConfig.warmTemp, 0)}',
      };

  static String _range(double from, double to) =>
      '${from.toInt()}–${to.toInt()}°';

  static HeatLevel? of(double? t) {
    if (t == null) return null;
    if (t > AppConfig.extremeTemp) return HeatLevel.extreme;
    if (t >= AppConfig.hotTemp) return HeatLevel.hot;
    if (t >= AppConfig.warmTemp) return HeatLevel.warm;
    return HeatLevel.cool;
  }
}

enum PriorityLevel {
  high('أولوية عالية', Color(0xFFFEE2E2), Color(0xFFB91C1C)),
  medium('أولوية متوسطة', Color(0xFFFFEDD5), Color(0xFFC2410C)),
  low('أولوية منخفضة', ZillColors.greenLight, ZillColors.greenDark),
  none('غير مرشحة', Color(0xFFE5E7EB), ZillColors.muted);

  const PriorityLevel(this.label, this.background, this.foreground);
  final String label;
  final Color background;
  final Color foreground;
}

/// منطقة كما يرسلها الـ Backend من GET /api/areas/
class Area {
  Area({
    required this.id,
    required this.name,
    this.temperature,
    this.classification,
    this.ndvi,
    this.priority,
    this.reason,
    this.impact,
    this.polygons = const [],
    this.point,
  });

  final int id;
  final String name;
  final double? temperature;
  final String? classification;
  final double? ndvi;
  final double? priority;
  final String? reason; // سبب جاهز إن أرسله الـ Backend
  final String? impact; // تقدير تأثير التشجير إن توفر علمياً
  final List<List<LatLng>> polygons; // حدود المنطقة (من GeoJSON)
  final LatLng? point; // أو نقطة واحدة

  bool get hasLocation => polygons.isNotEmpty || point != null;

  factory Area.fromJson(Map<String, dynamic> j, int index) {
    final lat = _num(j['lat'] ?? j['latitude']);
    final lng = _num(j['lng'] ?? j['lon'] ?? j['longitude']);
    return Area(
      id: (j['id'] as num?)?.toInt() ?? index + 1,
      name: (j['name'] as String?) ?? 'منطقة ${index + 1}',
      temperature: _num(j['temperature']),
      classification: j['classification'] as String?,
      ndvi: _num(j['ndvi']),
      priority: _num(j['planting_priority']),
      reason: j['reason'] as String?,
      impact: (j['cooling_estimate'] ?? j['impact']) as String?,
      polygons: _parseGeometry(j['geometry']),
      point: (lat != null && lng != null) ? LatLng(lat, lng) : null,
    );
  }

  HeatLevel? get heatLevel => HeatLevel.of(temperature);
  Color get color => heatLevel?.color ?? ZillColors.noData;

  static const _classAr = {
    'hotter': 'مرتفعة الحرارة',
    'hot': 'مرتفعة الحرارة',
    'high': 'مرتفعة الحرارة',
    'moderate': 'متوسطة الحرارة',
    'medium': 'متوسطة الحرارة',
    'cooler': 'منخفضة الحرارة',
    'cool': 'منخفضة الحرارة',
    'low': 'منخفضة الحرارة',
  };

  String get classificationAr {
    if (classification != null && classification!.trim().isNotEmpty) {
      return _classAr[classification!.trim().toLowerCase()] ?? classification!;
    }
    final t = temperature;
    if (t == null) return 'غير متوفر';
    if (t > AppConfig.extremeTemp) return 'مرتفعة الحرارة';
    if (t >= AppConfig.warmTemp) return 'متوسطة الحرارة';
    return 'منخفضة الحرارة';
  }

  bool get isCandidate =>
      temperature != null &&
      ndvi != null &&
      temperature! >= AppConfig.plantingMinTemp &&
      ndvi! < AppConfig.plantingMaxNdvi;

  bool get needsPlanting => (priority ?? 0) > 0 || isCandidate;

  PriorityLevel get priorityLevel {
    final p = priority;
    if (p == null || p <= 0) return PriorityLevel.none;
    if (p >= 70) return PriorityLevel.high;
    if (p >= 40) return PriorityLevel.medium;
    return PriorityLevel.low;
  }

  /// سبب اختيار المنطقة — مبني من أرقام المنطقة نفسها ومعايير التحليل
  List<String> get reasons {
    final r = <String>[];
    final t = temperature, n = ndvi, p = priority;
    if (t != null) {
      r.add(t >= AppConfig.plantingMinTemp
          ? 'حرارة سطح الأرض ${degWords(t)}، وهي أعلى من عتبة ${degWords(AppConfig.plantingMinTemp, 0)} المعتمدة في التحليل.'
          : 'حرارة سطح الأرض ${degWords(t)}، وهي أقل من عتبة ${degWords(AppConfig.plantingMinTemp, 0)}.');
    }
    if (n != null) {
      r.add(n < AppConfig.plantingMaxNdvi
          ? 'الغطاء النباتي ضعيف: قيمة NDVI هي ${fmt(n, 2)}، أي أقل من ${AppConfig.plantingMaxNdvi}.'
          : 'يوجد غطاء نباتي مقبول: قيمة NDVI هي ${fmt(n, 2)}.');
    }
    if (p != null && p > 0) {
      r.add('درجة أولوية التشجير ${fmt(p, 0)} من 100، وتجمع بين شدة الحرارة والقرب من المياه وقدرة التربة على حفظ الماء.');
    }
    if (reason != null && reason!.isNotEmpty) r.add(reason!);
    if (r.isEmpty) r.add('لا تتوفر بيانات كافية لهذه المنطقة.');
    return r;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// يدعم GeoJSON من نوع Polygon و MultiPolygon و Feature
  static List<List<LatLng>> _parseGeometry(dynamic g) {
    if (g is! Map) return const [];
    if (g['type'] == 'Feature') return _parseGeometry(g['geometry']);
    List<LatLng> ring(List coords) => coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    try {
      switch (g['type']) {
        case 'Polygon':
          return [ring((g['coordinates'] as List).first as List)];
        case 'MultiPolygon':
          return (g['coordinates'] as List)
              .map((poly) => ring((poly as List).first as List))
              .toList();
        case 'GeometryCollection':
          return (g['geometries'] as List).expand((x) => _parseGeometry(x)).toList();
      }
    } catch (_) {}
    return const [];
  }
}

/// تنسيق الأرقام بأرقام لاتينية
String fmt(num? v, [int digits = 1]) => v == null ? '—' : v.toStringAsFixed(digits);

/// درجة حرارة مختصرة (52.3°) — تُعرض داخل Text باتجاه LTR حتى لا تنقلب علامة °
String deg(num? v, [int digits = 1]) => v == null ? '—' : '${fmt(v, digits)}°';

/// درجة حرارة داخل جملة عربية
String degWords(num? v, [int digits = 1]) => v == null ? '—' : '${fmt(v, digits)} درجة مئوية';

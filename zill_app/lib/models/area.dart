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

  static HeatLevel? of(double? t) {
    if (t == null) return null;
    if (t > AppConfig.extremeTemp) return HeatLevel.extreme;
    if (t >= AppConfig.hotTemp) return HeatLevel.hot;
    if (t >= AppConfig.warmTemp) return HeatLevel.warm;
    return HeatLevel.cool;
  }
}

enum PriorityLevel {
  high('أعلى أولوية', Color(0xFFFEE2E2), Color(0xFFB91C1C)),
  medium('أولوية متوسطة', Color(0xFFFFEDD5), Color(0xFFC2410C)),
  low('أقل أولوية', ZillColors.greenLight, ZillColors.greenDark),
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
    this.district,
    this.level,
    this.builtUpRatio,
    this.waterDistanceM,
    this.soilWater,
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
  final String? district; // القضاء الذي تتبعه المنطقة؛ فارغ للأقضية نفسها
  final String? level; // حي أو ناحية
  final double? builtUpRatio; // نسبة المساحة المبنية (0-1)
  final double? waterDistanceM; // متوسط البعد عن المياه بالمتر
  final double? soilWater; // قدرة التربة على حفظ الماء (0-1)
  /// مستوى الأولوية نسبةً إلى بقية المناطق؛ يحدده assignRelativePriority
  PriorityLevel priorityLevel = PriorityLevel.none;
  final List<List<LatLng>> polygons; // حدود المنطقة (من GeoJSON)
  final LatLng? point; // أو نقطة واحدة

  bool get hasSiteData => builtUpRatio != null && waterDistanceM != null && soilWater != null;

  /// هل تقع النقطة داخل حدود المنطقة؟ (طريقة تقاطع الشعاع)
  bool contains(LatLng p) => polygons.any((ring) {
        var inside = false;
        for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
          final a = ring[i], b = ring[j];
          if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
              p.longitude <
                  (b.longitude - a.longitude) * (p.latitude - a.latitude) /
                          (b.latitude - a.latitude) +
                      a.longitude) {
            inside = !inside;
          }
        }
        return inside;
      });

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
      district: j['district'] as String?,
      level: j['level'] as String?,
      builtUpRatio: _num(j['built_up_ratio']),
      waterDistanceM: _num(j['water_distance_m']),
      soilWater: _num(j['soil_water']),
      polygons: parseGeometry(j['geometry']),
      point: (lat != null && lng != null) ? LatLng(lat, lng) : null,
    );
  }

  HeatLevel? get heatLevel => HeatLevel.of(temperature);
  Color get color => heatLevel?.color ?? ZillColors.noData;
  Color get coverageColor => coverageColorOf(ndvi);

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
  static List<List<LatLng>> parseGeometry(dynamic g) {
    if (g is! Map) return const [];
    if (g['type'] == 'Feature') return parseGeometry(g['geometry']);
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
          return (g['geometries'] as List).expand((x) => parseGeometry(x)).toList();
      }
    } catch (_) {}
    return const [];
  }
}

/// يقسم المناطق المرشحة حسب درجة الأولوية: نحو الثلث الأعلى، ثم الوسط، ثم نحو الثلث الأدنى.
/// الدرجات المطلقة لا تكفي للتصنيف لأنها متوسطات تعتمد أيضاً على المياه والتربة.
void assignRelativePriority(List<Area> areas) {
  final ranked = areas.where((a) => (a.priority ?? 0) > 0).toList()
    ..sort((a, b) => b.priority!.compareTo(a.priority!));
  final edge = (ranked.length * 0.3).round();
  for (final a in areas) {
    a.priorityLevel = PriorityLevel.none;
  }
  for (final (i, a) in ranked.indexed) {
    a.priorityLevel = i < edge
        ? PriorityLevel.high
        : (i >= ranked.length - edge ? PriorityLevel.low : PriorityLevel.medium);
  }
}

/// لون الغطاء النباتي لقيمة NDVI، بتدرج مستمر بين ألوان ZillColors.coverageStops
Color coverageColorOf(double? ndvi) {
  if (ndvi == null) return ZillColors.noData;
  const stops = ZillColors.coverageStops;
  if (ndvi <= stops.first.$1) return stops.first.$2;
  for (var i = 1; i < stops.length; i++) {
    if (ndvi <= stops[i].$1) {
      final t = (ndvi - stops[i - 1].$1) / (stops[i].$1 - stops[i - 1].$1);
      return Color.lerp(stops[i - 1].$2, stops[i].$2, t)!;
    }
  }
  return stops.last.$2;
}

/// تنسيق الأرقام بأرقام لاتينية
String fmt(num? v, [int digits = 1]) => v == null ? '—' : v.toStringAsFixed(digits);

/// درجة حرارة مختصرة (52.3°) — تُعرض داخل Text باتجاه LTR حتى لا تنقلب علامة °
String deg(num? v, [int digits = 1]) => v == null ? '—' : '${fmt(v, digits)}°';

/// درجة حرارة داخل جملة عربية
String degWords(num? v, [int digits = 1]) => v == null ? '—' : '${fmt(v, digits)} درجة مئوية';

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/area.dart';
import '../models/planting_site.dart';

enum LoadStatus { idle, loading, loaded, error }

/// يحمّل المناطق من الـ Backend ويشاركها بين كل الشاشات.
/// لا توجد أي أرقام افتراضية: كل الأرقام تأتي من الـ API.
class AreasStore extends ChangeNotifier {
  AreasStore({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  List<Area> areas = [];
  LoadStatus status = LoadStatus.idle;
  String? error;
  int? selectedId;
  List<Area> subAreas = [];
  int? drilledId; // القضاء المفتوح على الخريطة
  List<PlantingSite> sites = [];
  int? selectedSiteId;

  Area? get selected =>
      selectedId == null ? null : _allAreas.where((a) => a.id == selectedId).firstOrNull;

  Iterable<Area> get _allAreas => areas.followedBy(subAreas);

  Area? get drilled =>
      drilledId == null ? null : areas.where((a) => a.id == drilledId).firstOrNull;

  /// مناطق القضاء من الأقل غطاءً نباتياً إلى الأكثر
  List<Area> subAreasOf(Area district) => subAreas.where((a) => a.district == district.name).toList()
    ..sort((a, b) => (a.ndvi ?? double.infinity).compareTo(b.ndvi ?? double.infinity));

  /// ما يظهر على الخريطة: الأقضية، وعند فتح قضاء تحل مناطقه محله
  List<Area> get visibleAreas {
    final open = drilled;
    if (open == null) return areas;
    return [...areas.where((a) => a.id != open.id), ...subAreasOf(open)];
  }

  Area? areaById(int? id) => id == null ? null : _allAreas.where((a) => a.id == id).firstOrNull;

  Future<void> load() async {
    status = LoadStatus.loading;
    error = null;
    notifyListeners();
    try {
      final res = await _client
          .get(Uri.parse(AppConfig.apiBase + AppConfig.areasEndpoint),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final list = data is List ? data : (data['areas'] as List? ?? []);
      areas = [
        for (var i = 0; i < list.length; i++)
          Area.fromJson(Map<String, dynamic>.from(list[i] as Map), i)
      ];
      assignRelativePriority(areas);
      sites = await _loadSites();
      subAreas = await _loadSubAreas();
      status = LoadStatus.loaded;
    } catch (e) {
      debugPrint('تعذر تحميل المناطق: $e');
      error = 'تعذر الاتصال بالخادم. تأكد من تشغيل الـ Backend.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// معرّفات المناطق تُزاح حتى لا تتداخل مع معرّفات الأقضية
  static const _subAreaIdOffset = 1000000;

  /// المناطق الداخلية ميزة إضافية أيضاً؛ وأولويتها نسبية داخل كل قضاء
  Future<List<Area>> _loadSubAreas() async {
    try {
      final res = await _client
          .get(Uri.parse(AppConfig.apiBase + AppConfig.subAreasEndpoint),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      final result = [
        for (final (i, j) in list.indexed)
          Area.fromJson(
            {...Map<String, dynamic>.from(j as Map), 'id': _subAreaIdOffset + (j['id'] as num).toInt()},
            i,
          )
      ];
      for (final d in result.map((a) => a.district).toSet()) {
        assignRelativePriority(result.where((a) => a.district == d).toList());
      }
      return result;
    } catch (e) {
      debugPrint('تعذر تحميل المناطق الداخلية: $e');
      return [];
    }
  }

  /// المواقع ميزة إضافية: تعذر تحميلها لا يمنع عرض الأقضية
  Future<List<PlantingSite>> _loadSites() async {
    try {
      final res = await _client
          .get(Uri.parse(AppConfig.apiBase + AppConfig.sitesEndpoint),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return [for (final j in list) PlantingSite.fromJson(Map<String, dynamic>.from(j as Map))];
    } catch (e) {
      debugPrint('تعذر تحميل مواقع التشجير: $e');
      return [];
    }
  }

  void select(int? id) {
    selectedId = id;
    if (id != null) {
      selectedSiteId = null;
      // اختيار قضاء يفتح مناطقه
      if (areas.any((a) => a.id == id)) drilledId = id;
    }
    notifyListeners();
  }

  void selectSite(int? id) {
    selectedSiteId = id;
    if (id != null) {
      selectedId = null;
      final district = sites.where((s) => s.id == id).firstOrNull?.district;
      drilledId = areas.where((a) => a.name == district).firstOrNull?.id ?? drilledId;
    }
    notifyListeners();
  }

  /// العودة إلى عرض كل الأقضية
  void closeDistrict() {
    drilledId = null;
    selectedId = null;
    selectedSiteId = null;
    notifyListeners();
  }

  PlantingSite? get selectedSite =>
      selectedSiteId == null ? null : sites.where((s) => s.id == selectedSiteId).firstOrNull;

  Iterable<PlantingSite> sitesIn(Area area) => area.district == null
      ? sites.where((s) => s.district == area.name)
      : sites.where((s) => s.district == area.district && area.contains(s.point));

  // ---------- إحصائيات ----------
  Iterable<double> get _temps => areas.map((a) => a.temperature).whereType<double>();

  int get hotCount =>
      areas.where((a) => (a.temperature ?? -999) >= AppConfig.hotTemp).length;
  int get lowCoverageCount =>
      areas.where((a) => a.ndvi != null && a.ndvi! < AppConfig.plantingMaxNdvi).length;
  int get needPlantingCount => areas.where((a) => a.needsPlanting).length;
  double? get maxTemp => _temps.isEmpty ? null : _temps.reduce((a, b) => a > b ? a : b);
  double? get avgTemp =>
      _temps.isEmpty ? null : _temps.reduce((a, b) => a + b) / _temps.length;

  List<Area> get byTemperature => [...areas]
    ..sort((a, b) => (b.temperature ?? -999).compareTo(a.temperature ?? -999));

  /// من الأقل غطاءً نباتياً إلى الأكثر، والمناطق بلا بيانات في النهاية
  List<Area> get byVegetation => [...areas]
    ..sort((a, b) => (a.ndvi ?? double.infinity).compareTo(b.ndvi ?? double.infinity));

  /// المناطق المقترحة للتشجير مرتبة حسب الأولوية ثم الحرارة
  List<Area> get recommendations => areas.where((a) => a.needsPlanting).toList()
    ..sort((a, b) {
      final c = (b.priority ?? 0).compareTo(a.priority ?? 0);
      return c != 0 ? c : (b.temperature ?? 0).compareTo(a.temperature ?? 0);
    });
}

/// يوفّر AreasStore لكل الشاشات
class AreasScope extends InheritedNotifier<AreasStore> {
  const AreasScope({super.key, required AreasStore store, required super.child})
      : super(notifier: store);

  static AreasStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AreasScope>()!.notifier!;
}

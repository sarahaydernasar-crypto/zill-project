import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/area.dart';

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

  Area? get selected =>
      selectedId == null ? null : areas.where((a) => a.id == selectedId).firstOrNull;

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
      status = LoadStatus.loaded;
    } catch (e) {
      debugPrint('تعذر تحميل المناطق: $e');
      error = 'تعذر الاتصال بالخادم. تأكد من تشغيل الـ Backend.';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  void select(int? id) {
    selectedId = id;
    notifyListeners();
  }

  // ---------- إحصائيات ----------
  Iterable<double> get _temps => areas.map((a) => a.temperature).whereType<double>();

  int get hotCount =>
      areas.where((a) => (a.temperature ?? -999) >= AppConfig.hotTemp).length;
  int get needPlantingCount => areas.where((a) => a.needsPlanting).length;
  double? get maxTemp => _temps.isEmpty ? null : _temps.reduce((a, b) => a > b ? a : b);
  double? get avgTemp =>
      _temps.isEmpty ? null : _temps.reduce((a, b) => a + b) / _temps.length;

  List<Area> get byTemperature => [...areas]
    ..sort((a, b) => (b.temperature ?? -999).compareTo(a.temperature ?? -999));

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

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/green_points.dart';
import 'community_store.dart' show ApiError, PickedPhoto;

/// حساب المستخدم ونقاطه، والأشجار المعتمدة على الخريطة
class GreenStore extends ChangeNotifier {
  GreenStore({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  GreenRules? rules;
  List<RegisteredTree> trees = [];
  GreenDashboard? dashboard;
  String? username;
  String? token; // في الذاكرة فقط: تحديث الصفحة يتطلب تسجيل الدخول مجدداً

  bool get isLoggedIn => token != null;

  static Uri _uri(String path) => Uri.parse(AppConfig.apiBase + path);

  Map<String, String> get _auth => {if (token != null) 'Authorization': 'Bearer $token'};

  dynamic _decode(http.Response res) {
    final body = res.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401 && token != null) logout();
    final detail = body is Map ? body['detail'] : null;
    if (res.statusCode == 422 && detail is! String) throw ApiError('تأكد من صحة البيانات المدخلة.');
    throw ApiError(detail is String ? detail : 'تعذر تنفيذ الطلب (${res.statusCode}).');
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 30));
    } on ApiError {
      rethrow;
    } catch (e) {
      debugPrint('خطأ في الاتصال: $e');
      throw ApiError('تعذر الاتصال بالخادم. تأكد من تشغيل الـ Backend.');
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) => _guard(() async => _decode(await _client.post(
        _uri(path),
        headers: {..._auth, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )));

  Future<dynamic> _multipart(String path, Map<String, String> fields, PickedPhoto photo) => _guard(() async {
        final request = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_auth)
          ..fields.addAll(fields)
          ..files.add(http.MultipartFile.fromBytes('photo', photo.bytes, filename: photo.name));
        return _decode(await http.Response.fromStream(await _client.send(request)));
      });

  // ---------- البيانات العامة ----------
  Future<void> loadPublic() async {
    try {
      final data = await Future.wait([
        _guard(() async => _decode(await _client.get(_uri('/api/points/rules')))),
        _guard(() async => _decode(await _client.get(_uri('/api/trees/')))),
      ]);
      rules = GreenRules.fromJson(Map<String, dynamic>.from(data[0] as Map));
      trees = [for (final t in data[1] as List) RegisteredTree.fromJson(Map<String, dynamic>.from(t as Map))];
      notifyListeners();
    } on ApiError catch (e) {
      debugPrint('تعذر تحميل بيانات النقاط: $e');
    }
  }

  // ---------- الحساب ----------
  Future<void> _startSession(String path, String name, String password) async {
    final data = await _post(path, {'username': name, 'password': password});
    token = data['token'] as String;
    username = data['username'] as String;
    await loadDashboard();
  }

  Future<void> login(String name, String password) => _startSession('/api/users/login', name, password);

  Future<void> register(String name, String password) => _startSession('/api/users/register', name, password);

  void logout() {
    token = null;
    username = null;
    dashboard = null;
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    final data = await _guard(() async => _decode(await _client.get(_uri('/api/users/me'), headers: _auth)));
    dashboard = GreenDashboard.fromJson(Map<String, dynamic>.from(data as Map));
    notifyListeners();
  }

  /// يحدّث الأشجار والقيم، ورصيد المستخدم إن كان مسجلاً
  Future<void> refresh() async {
    await loadPublic();
    if (!isLoggedIn) return;
    try {
      await loadDashboard();
    } on ApiError catch (e) {
      debugPrint('تعذر تحديث لوحة النقاط: $e');
    }
  }

  // ---------- الأشجار والاستبدال ----------
  Future<void> registerTree({
    required String name,
    required double lat,
    required double lng,
    required String plantedOn,
    required String contributor,
    required PickedPhoto photo,
  }) async {
    await _multipart(
      '/api/trees/',
      {'name': name, 'lat': '$lat', 'lng': '$lng', 'planted_on': plantedOn, 'contributor': contributor},
      photo,
    );
    await loadDashboard();
  }

  Future<void> addTreeUpdate(int treeId, String status, String note, PickedPhoto photo) async {
    await _multipart('/api/trees/$treeId/updates', {'status': status, 'note': note}, photo);
    await loadDashboard();
  }

  Future<void> redeem(String reward, String phone) async {
    await _post('/api/points/redeem', {'reward': reward, 'phone': phone});
    await loadDashboard();
  }
}

class GreenScope extends InheritedNotifier<GreenStore> {
  const GreenScope({super.key, required GreenStore store, required super.child}) : super(notifier: store);

  static GreenStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GreenScope>()!.notifier!;
}

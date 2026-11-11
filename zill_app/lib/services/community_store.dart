import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/campaign.dart';

/// خطأ يمكن عرض رسالته للمستخدم
class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// صورة مختارة من الجهاز
class PickedPhoto {
  PickedPhoto(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// البلاغات والحملات وجلسة المشرف
class CommunityStore extends ChangeNotifier {
  CommunityStore({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  List<Campaign> campaigns = [];
  String? _token; // في الذاكرة فقط: تحديث الصفحة يتطلب تسجيل الدخول مجدداً
  String? adminName;

  bool get isAdmin => _token != null;

  static Uri _uri(String path) => Uri.parse(AppConfig.apiBase + path);
  static String photoUrl(String path) => AppConfig.apiBase + path;

  Map<String, String> get _auth => {if (_token != null) 'Authorization': 'Bearer $_token'};

  /// يفك الاستجابة، أو يرمي رسالة الخادم
  dynamic _decode(http.Response res) {
    final body = res.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401 && _token != null) {
      _token = null;
      adminName = null;
      notifyListeners();
    }
    final detail = body is Map ? body['detail'] : null;
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

  Future<dynamic> _json(String method, String path, Map<String, dynamic> body) => _guard(() async {
        final request = http.Request(method, _uri(path))
          ..headers.addAll({..._auth, 'Content-Type': 'application/json'})
          ..body = jsonEncode(body);
        return _decode(await http.Response.fromStream(await _client.send(request)));
      });

  // ---------- المشرف ----------
  Future<void> login(String username, String password) async {
    final data = await _json('POST', '/api/auth/login', {'username': username, 'password': password});
    _token = data['token'] as String;
    adminName = data['username'] as String;
    notifyListeners();
  }

  void logout() {
    _token = null;
    adminName = null;
    notifyListeners();
  }

  // ---------- البلاغات ----------
  Future<String> submitReport({
    required String type,
    required String area,
    required String description,
    PickedPhoto? photo,
    String? userToken,
  }) =>
      _guard(() async {
        final request = http.MultipartRequest('POST', _uri('/api/reports/'))
          ..fields.addAll({'report_type': type, 'area_name': area, 'description': description});
        if (userToken != null) request.headers['Authorization'] = 'Bearer $userToken';
        if (photo != null) {
          request.files.add(http.MultipartFile.fromBytes('photo', photo.bytes, filename: photo.name));
        }
        final data = _decode(await http.Response.fromStream(await _client.send(request)));
        return data['tracking_code'] as String;
      });

  Future<Map<String, dynamic>> trackReport(String code) => _guard(() async {
        final path = '/api/reports/track/${Uri.encodeComponent(code.trim())}';
        return Map<String, dynamic>.from(_decode(await _client.get(_uri(path))) as Map);
      });

  Future<List<Map<String, dynamic>>> listReports() => _guard(() async {
        final list = _decode(await _client.get(_uri('/api/reports/'), headers: _auth)) as List;
        return [for (final r in list) Map<String, dynamic>.from(r as Map)];
      });

  Future<void> updateReport(int id, String status, String? note) =>
      _json('PATCH', '/api/reports/$id', {'status': status, 'admin_note': note});

  // ---------- مراجعة الأشجار والنقاط ----------
  Future<Map<String, dynamic>> pendingReviews() => _guard(() async {
        return Map<String, dynamic>.from(_decode(await _client.get(_uri('/api/trees/pending'), headers: _auth)) as Map);
      });

  Future<void> reviewTree(int id, String decision, String? note) =>
      _json('PATCH', '/api/trees/$id/review', {'decision': decision, 'admin_note': note});

  Future<void> reviewUpdate(int id, String decision, String? note) =>
      _json('PATCH', '/api/trees/updates/$id/review', {'decision': decision, 'admin_note': note});

  Future<List<Map<String, dynamic>>> listRedemptions() => _guard(() async {
        final list = _decode(await _client.get(_uri('/api/points/redemptions'), headers: _auth)) as List;
        return [for (final r in list) Map<String, dynamic>.from(r as Map)];
      });

  Future<void> updateRedemption(int id, String status, String? note) =>
      _json('PATCH', '/api/points/redemptions/$id', {'status': status, 'admin_note': note});

  Future<void> addCampaignParticipant(int campaignId, String username) =>
      _json('POST', '/api/campaigns/$campaignId/participants', {'username': username});

  // ---------- الحملات ----------
  Future<void> loadCampaigns() async {
    try {
      final list = await _guard(() async => _decode(await _client.get(_uri('/api/campaigns/'))) as List);
      campaigns = [for (final c in list) Campaign.fromJson(Map<String, dynamic>.from(c as Map))];
      notifyListeners();
    } on ApiError catch (e) {
      debugPrint('تعذر تحميل الحملات: $e');
    }
  }

  Future<void> saveCampaign(Map<String, dynamic> fields, {int? id}) async {
    await _json(id == null ? 'POST' : 'PUT', id == null ? '/api/campaigns/' : '/api/campaigns/$id', fields);
    await loadCampaigns();
  }

  Future<void> deleteCampaign(int id) async {
    await _guard(() async => _decode(await _client.delete(_uri('/api/campaigns/$id'), headers: _auth)));
    await loadCampaigns();
  }

  Future<void> uploadCampaignPhoto(int id, String kind, PickedPhoto photo) async {
    await _guard(() async {
      final request = http.MultipartRequest('POST', _uri('/api/campaigns/$id/photo/$kind'))
        ..headers.addAll(_auth)
        ..files.add(http.MultipartFile.fromBytes('photo', photo.bytes, filename: photo.name));
      return _decode(await http.Response.fromStream(await _client.send(request)));
    });
    await loadCampaigns();
  }
}

class CommunityScope extends InheritedNotifier<CommunityStore> {
  const CommunityScope({super.key, required CommunityStore store, required super.child})
      : super(notifier: store);

  static CommunityStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommunityScope>()!.notifier!;
}

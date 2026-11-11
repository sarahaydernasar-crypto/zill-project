import 'package:latlong2/latlong.dart' show LatLng;

const treeStatuses = {'healthy': 'بحالة جيدة', 'needs_care': 'تحتاج إلى عناية', 'dead': 'لم تعش'};
const reviewStatuses = {'pending': 'قيد المراجعة', 'approved': 'معتمدة', 'rejected': 'مرفوضة'};
const redeemRewards = {'phone_credit': 'رصيد آسياسيل', 'store_discount': 'خصم من متجر مشارك'};
const redeemStatuses = {'pending': 'قيد المراجعة', 'completed': 'تم التنفيذ', 'rejected': 'مرفوض'};

/// قيم النقاط كما يحددها الخادم
class GreenRules {
  const GreenRules({
    required this.treesPerReward,
    required this.pointsPerReward,
    required this.campaignPoints,
    required this.survivalPoints,
    required this.updatePoints,
    required this.updateIntervalDays,
    required this.reportPoints,
    required this.redeemPoints,
  });

  factory GreenRules.fromJson(Map<String, dynamic> j) => GreenRules(
        treesPerReward: j['trees_per_reward'] as int,
        pointsPerReward: j['points_per_reward'] as int,
        campaignPoints: j['campaign_points'] as int,
        survivalPoints: j['survival_points'] as int,
        updatePoints: j['update_points'] as int,
        updateIntervalDays: j['update_interval_days'] as int,
        reportPoints: j['report_points'] as int,
        redeemPoints: j['redeem_points'] as int,
      );

  final int treesPerReward;
  final int pointsPerReward;
  final int campaignPoints;
  final int survivalPoints;
  final int updatePoints;
  final int updateIntervalDays;
  final int reportPoints;
  final int redeemPoints;

  /// عدد الأشجار اللازم للوصول إلى حد الاستبدال من الزراعة وحدها
  int get treesToRedeem => (redeemPoints / pointsPerReward).ceil() * treesPerReward;

  List<({String title, String detail, int points})> get earnWays => [
        (title: 'زراعة $treesPerReward أشجار', detail: 'لكل $treesPerReward أشجار يعتمدها المشرف', points: pointsPerReward),
        (title: 'المشاركة في حملة تشجير', detail: 'لكل حملة يؤكد المشرف حضورك فيها', points: campaignPoints),
        (title: 'بقاء الشجرة حية بعد سنة', detail: 'مرة لكل شجرة، بعد سنة من تسجيلها', points: survivalPoints),
        (title: 'متابعة نمو الشجرة', detail: 'لكل صورة متابعة تُعتمد، مرة كل $updateIntervalDays يوماً', points: updatePoints),
        (title: 'بلاغ صحيح', detail: 'لكل بلاغ تتم معالجته وأنت مسجل الدخول', points: reportPoints),
      ];
}

/// صياغة عدد النقاط بالعربية
String pointsLabel(int points) => switch (points) {
      1 => 'نقطة',
      2 => 'نقطتان',
      >= 3 && <= 10 => '$points نقاط',
      _ => '$points نقطة',
    };

class TreeUpdate {
  const TreeUpdate({
    required this.status,
    required this.date,
    this.note,
    this.photo,
    this.reviewStatus,
  });

  factory TreeUpdate.fromJson(Map<String, dynamic> j) => TreeUpdate(
        status: j['status'] as String,
        date: (j['created_at'] as String).substring(0, 10),
        note: j['note'] as String?,
        photo: j['photo'] as String?,
        reviewStatus: j['review_status'] as String?,
      );

  final String status;
  final String date;
  final String? note;
  final String? photo;
  final String? reviewStatus;
}

/// شجرة سجلها مستخدم
class RegisteredTree {
  const RegisteredTree({
    required this.id,
    required this.name,
    required this.point,
    required this.plantedOn,
    required this.status,
    required this.contributor,
    this.photo,
    this.reviewStatus,
    this.adminNote,
    this.updates = const [],
  });

  factory RegisteredTree.fromJson(Map<String, dynamic> j) => RegisteredTree(
        id: j['id'] as int,
        name: j['name'] as String,
        point: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        plantedOn: j['planted_on'] as String,
        status: j['status'] as String,
        contributor: j['contributor'] as String,
        photo: j['photo'] as String?,
        reviewStatus: j['review_status'] as String?,
        adminNote: j['admin_note'] as String?,
        updates: [
          for (final u in (j['updates'] as List? ?? const []))
            TreeUpdate.fromJson(Map<String, dynamic>.from(u as Map)),
        ],
      );

  final int id;
  final String name;
  final LatLng point;
  final String plantedOn;
  final String status;
  final String contributor;
  final String? photo;
  final String? reviewStatus;
  final String? adminNote;
  final List<TreeUpdate> updates;

  String get statusLabel => treeStatuses[status] ?? status;
}

/// لوحة نقاط المستخدم
class GreenDashboard {
  const GreenDashboard({
    required this.balance,
    required this.entries,
    required this.trees,
    required this.redemptions,
  });

  factory GreenDashboard.fromJson(Map<String, dynamic> j) => GreenDashboard(
        balance: j['balance'] as int,
        entries: [for (final e in j['entries'] as List) Map<String, dynamic>.from(e as Map)],
        trees: [for (final t in j['trees'] as List) RegisteredTree.fromJson(Map<String, dynamic>.from(t as Map))],
        redemptions: [for (final r in j['redemptions'] as List) Map<String, dynamic>.from(r as Map)],
      );

  final int balance;
  final List<Map<String, dynamic>> entries;
  final List<RegisteredTree> trees;
  final List<Map<String, dynamic>> redemptions;
}

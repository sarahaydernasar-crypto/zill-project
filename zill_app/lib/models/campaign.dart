import 'package:latlong2/latlong.dart';

/// قياس الأقمار الصناعية قبل الزراعة وبعدها، للموقع وللحلقة المحيطة به
class CampaignMeasurement {
  CampaignMeasurement(this._j);
  final Map<String, dynamic> _j;

  double? _n(String key) => (_j[key] as num?)?.toDouble();

  String? get periodBefore => _j['period_before'] as String?;
  String? get periodAfter => _j['period_after'] as String?;
  double? get ndviBefore => _n('ndvi_before');
  double? get ndviAfter => _n('ndvi_after');
  double? get tempBefore => _n('temp_before');
  double? get tempAfter => _n('temp_after');
  double? get greenHaBefore => _n('green_ha_before');
  double? get greenHaAfter => _n('green_ha_after');
  double? get refNdviBefore => _n('ref_ndvi_before');
  double? get refNdviAfter => _n('ref_ndvi_after');
  double? get refTempBefore => _n('ref_temp_before');
  double? get refTempAfter => _n('ref_temp_after');

  /// تغير الموقع مطروحاً منه تغير محيطه، حتى لا يُنسب اختلاف الطقس بين السنتين إلى التشجير
  double? _net(double? a, double? b, double? refA, double? refB) =>
      a == null || b == null || refA == null || refB == null ? null : (b - a) - (refB - refA);

  double? get netNdvi => _net(ndviBefore, ndviAfter, refNdviBefore, refNdviAfter);
  double? get netTemp => _net(tempBefore, tempAfter, refTempBefore, refTempAfter);
}

enum TreeCondition {
  healthy('جيدة'),
  needsCare('تحتاج إلى عناية'),
  damaged('متضررة'),
  unknown('غير محددة');

  const TreeCondition(this.label);
  final String label;

  String get api => switch (this) {
        TreeCondition.healthy => 'healthy',
        TreeCondition.needsCare => 'needs_care',
        TreeCondition.damaged => 'damaged',
        TreeCondition.unknown => 'unknown',
      };

  static TreeCondition parse(String? v) =>
      values.where((c) => c.api == v).firstOrNull ?? TreeCondition.unknown;
}

class Campaign {
  Campaign({
    required this.id,
    required this.name,
    required this.areaName,
    required this.point,
    required this.radiusM,
    required this.plantedOn,
    required this.treesPlanted,
    this.treesAlive,
    this.species,
    this.condition = TreeCondition.unknown,
    this.notes,
    this.photoBefore,
    this.photoAfter,
    this.measurement,
  });

  final int id;
  final String name;
  final String areaName;
  final LatLng point;
  final double radiusM;
  final DateTime plantedOn;
  final int treesPlanted;
  final int? treesAlive;
  final String? species;
  final TreeCondition condition;
  final String? notes;
  final String? photoBefore;
  final String? photoAfter;
  final CampaignMeasurement? measurement;

  /// نسبة الأشجار الحية؛ فارغة إذا لم يُسجل عددها بعد
  double? get successRate => treesAlive == null ? null : treesAlive! / treesPlanted;

  String get plantedOnText =>
      '${plantedOn.year}-${plantedOn.month.toString().padLeft(2, '0')}-${plantedOn.day.toString().padLeft(2, '0')}';

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        areaName: j['area_name'] as String,
        point: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        radiusM: (j['radius_m'] as num).toDouble(),
        plantedOn: DateTime.parse(j['planted_on'] as String),
        treesPlanted: (j['trees_planted'] as num).toInt(),
        treesAlive: (j['trees_alive'] as num?)?.toInt(),
        species: j['tree_species'] as String?,
        condition: TreeCondition.parse(j['condition'] as String?),
        notes: j['notes'] as String?,
        photoBefore: j['photo_before'] as String?,
        photoAfter: j['photo_after'] as String?,
        measurement: j['measurement'] == null
            ? null
            : CampaignMeasurement(Map<String, dynamic>.from(j['measurement'] as Map)),
      );
}

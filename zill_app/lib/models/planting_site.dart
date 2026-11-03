import 'package:latlong2/latlong.dart';

import 'area.dart';

/// موقع تشجير محتمل داخل قضاء، كما يرسله الـ Backend من GET /api/sites/
class PlantingSite {
  PlantingSite({
    required this.id,
    required this.district,
    required this.point,
    this.place,
    this.areaHa,
    this.temperature,
    this.ndvi,
    this.priority,
    this.waterDistanceM,
    this.polygons = const [],
  });

  final int id;
  final String district;
  final LatLng point;
  final String? place; // أقرب حي أو شارع إن وُجد
  final double? areaHa;
  final double? temperature;
  final double? ndvi;
  final double? priority;
  final double? waterDistanceM;
  final List<List<LatLng>> polygons;

  String get title => place ?? 'موقع في $district';

  factory PlantingSite.fromJson(Map<String, dynamic> j) {
    double? n(String key) => (j[key] as num?)?.toDouble();
    return PlantingSite(
      id: (j['id'] as num).toInt(),
      district: j['district'] as String,
      point: LatLng(n('lat')!, n('lng')!),
      place: j['place'] as String?,
      areaHa: n('area_ha'),
      temperature: n('temperature'),
      ndvi: n('ndvi'),
      priority: n('planting_priority'),
      waterDistanceM: n('water_distance_m'),
      polygons: Area.parseGeometry(j['geometry']),
    );
  }
}

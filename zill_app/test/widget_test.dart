import 'package:flutter_test/flutter_test.dart';
import 'package:zill_app/models/area.dart';

void main() {
  test('Area.fromJson يقرأ بيانات الـ API ويحسب التصنيفات', () {
    final a = Area.fromJson({
      'id': 1,
      'name': 'الكرخ',
      'temperature': 48.5,
      'classification': 'Moderate',
      'ndvi': 0.15,
      'planting_priority': 72.0,
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [[44.3, 33.3], [44.4, 33.3], [44.4, 33.4], [44.3, 33.3]]
        ],
      },
    }, 0);

    expect(a.heatLevel, HeatLevel.hot);
    expect(a.classificationAr, 'متوسطة الحرارة');
    expect(a.isCandidate, isTrue);
    expect(a.priorityLevel, PriorityLevel.high);
    expect(a.polygons.single.first.latitude, 33.3);
    expect(a.reasons.length, 3);
  });

  test('منطقة بدون أرقام لا تُرشَّح', () {
    final a = Area.fromJson({'name': 'x'}, 0);
    expect(a.heatLevel, isNull);
    expect(a.needsPlanting, isFalse);
    expect(a.priorityLevel, PriorityLevel.none);
  });
}

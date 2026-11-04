import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zill_app/services/areas_store.dart';
import 'package:zill_app/theme.dart';
import 'package:zill_app/models/area.dart';
import 'package:zill_app/models/assistant.dart';
import 'package:zill_app/models/campaign.dart';
import 'package:zill_app/models/green_points.dart';
import 'package:zill_app/models/impact.dart';
import 'package:zill_app/models/planting_site.dart';
import 'package:zill_app/models/trees.dart';

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
    expect(a.polygons.single.first.latitude, 33.3);
    expect(a.reasons.length, 3);
  });

  test('منطقة بدون أرقام لا تُرشَّح', () {
    final a = Area.fromJson({'name': 'x'}, 0);
    expect(a.heatLevel, isNull);
    expect(a.needsPlanting, isFalse);
    expect(a.priorityLevel, PriorityLevel.none);
  });

  test('الأولوية نسبية: ثلث أعلى ووسط وثلث أدنى، وغير المرشحة خارجها', () {
    final areas = [
      for (final (i, p) in [36.4, 35.1, 24.4, 21.3, 20.0, 17.4, 14.2, 0.0].indexed)
        Area(id: i, name: '\$i', priority: p),
    ];
    assignRelativePriority(areas);
    expect(areas.map((a) => a.priorityLevel), [
      PriorityLevel.high, PriorityLevel.high,
      PriorityLevel.medium, PriorityLevel.medium, PriorityLevel.medium,
      PriorityLevel.low, PriorityLevel.low,
      PriorityLevel.none,
    ]);
  });

  test('موقع التشجير يقرأ بيانات الـ API ويعطي عنواناً بديلاً دون اسم مكان', () {
    final s = PlantingSite.fromJson({
      'id': 5,
      'district': 'الكرخ',
      'place': null,
      'lat': 33.3,
      'lng': 44.3,
      'area_ha': 2.5,
      'planting_priority': 60.0,
      'geometry': {
        'type': 'MultiPolygon',
        'coordinates': [
          [[[44.3, 33.3], [44.4, 33.3], [44.4, 33.4], [44.3, 33.3]]]
        ],
      },
    });
    expect(s.title, 'موقع في الكرخ');
    expect(s.polygons, hasLength(1));
    expect(s.areaHa, 2.5);
  });

  test('فتح قضاء يعرض مناطقه مكانه، والعودة ترجع الأقضية', () {
    final d1 = Area(id: 1, name: 'المحمودية');
    final d2 = Area(id: 2, name: 'الكرخ');
    final s1 = Area(id: 11, name: 'اليوسفية', district: 'المحمودية', ndvi: 0.3);
    final s2 = Area(id: 12, name: 'اللطيفية', district: 'المحمودية', ndvi: 0.1);
    final s3 = Area(id: 13, name: 'المنصور', district: 'الكرخ', ndvi: 0.2);
    final store = AreasStore()
      ..areas = [d1, d2]
      ..subAreas = [s1, s2, s3];

    expect(store.visibleAreas, [d1, d2]);
    store.select(1);
    expect(store.drilled, d1);
    expect(store.subAreasOf(d1), [s2, s1]);
    expect(store.visibleAreas, [d2, s2, s1]);

    // اختيار منطقة داخلية يبقي القضاء مفتوحاً
    store.select(11);
    expect(store.selected, s1);
    expect(store.drilled, d1);

    store.closeDistrict();
    expect(store.visibleAreas, [d1, d2]);
    expect(store.selected, isNull);
  });

  test('تحديد المناطق التي تقع فيها النقطة', () {
    final a = Area.fromJson({
      'name': 'x',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [[44.0, 33.0], [44.2, 33.0], [44.2, 33.2], [44.0, 33.2], [44.0, 33.0]]
        ],
      },
    }, 0);
    expect(a.contains(const LatLng(33.1, 44.1)), isTrue);
    expect(a.contains(const LatLng(33.3, 44.1)), isFalse);
  });

  group('المساعد', () {
    Assistant build() {
      final store = AreasStore()
        ..areas = [
          Area(id: 1, name: 'الكرخ', temperature: 51, ndvi: 0.18, priority: 24, builtUpRatio: 0.5, waterDistanceM: 1500, soilWater: 0.6),
          Area(id: 2, name: 'المدائن', temperature: 55, ndvi: 0.16, priority: 21),
          Area(id: 3, name: 'المحمودية', temperature: 52, ndvi: 0.26, priority: 36),
        ]
        ..subAreas = [
          Area(id: 11, name: 'ناحية اليوسفية', district: 'المحمودية', temperature: 50, ndvi: 0.3, priority: 38),
          Area(id: 12, name: 'ناحية الرشيد', district: 'المحمودية', temperature: 53, ndvi: 0.1, priority: 36),
        ];
      return Assistant(store, const []);
    }

    test('أكثر المناطق حرارة من البيانات', () {
      final r = build().answer('ما أكثر مناطق بغداد حرارة؟');
      expect(r.text, contains('المدائن'));
      expect(r.areaId, 2);
    });

    test('السؤال عن قضاء يبحث داخل مناطقه', () {
      final r = build().answer('ما اكثر المناطق حرارة في المحمودية');
      expect(r.areaId, 12);
    });

    test('لماذا يحدد المنطقة ويذكر رقمها', () {
      final r = build().answer('لماذا تم اختيار المحمودية؟');
      expect(r.areaId, 3);
      expect(r.text, contains('52.0'));
    });

    test('الأشجار تستخدم قواعد الاقتراح', () {
      final r = build().answer('ما أنواع الأشجار المناسبة للكرخ؟');
      expect(r.areaId, 1);
      expect(r.text, contains('اللبخ'));
    });

    test('الأشجار بصيغة «الأشجار» دون كلمة أنواع', () {
      final r = build().answer('ما الأشجار المناسبة للكرخ؟');
      expect(r.text, contains('الأشجار المقترحة'));
    });

    test('التدخل العاجل يطبق المعيار المذكور', () {
      final r = build().answer('ما المناطق التي تحتاج إلى تدخل عاجل؟');
      expect(r.areaId, 12);
      expect(r.text, isNot(contains('اليوسفية')));
    });

    test('سؤال خارج البيانات لا يخترع إجابة', () {
      expect(build().answer('ما عاصمة فرنسا؟').text, contains('لم أفهم'));
    });

    test('بدون بيانات لا يجيب بأرقام', () {
      expect(Assistant(AreasStore(), const []).answer('ما أكثر المناطق حرارة؟').text, contains('لا تتوفر'));
    });
  });

  test('تقدير الأثر يعطي نطاقاً متسقاً مع الافتراضات', () {
    final i = SiteImpact(2);
    expect(i.treesLow, 200);
    expect(i.treesHigh, 556);
    expect(i.canopyHaLow, closeTo(0.6, 1e-9));
    // 0.6 هكتار × 10000 × 1.0276 كغم = نحو 6.2 طن
    expect(i.co2TonsPerYearLow, closeTo(6.17, 0.01));
    expect(i.co2TonsPerYearHigh, greaterThan(i.co2TonsPerYearLow));
  });

  test('الصافي يطرح تغير المحيط، ونسبة النجاح من الأعداد', () {
    final m = CampaignMeasurement({
      'ndvi_before': 0.10, 'ndvi_after': 0.20, 'ref_ndvi_before': 0.15, 'ref_ndvi_after': 0.18,
      'temp_before': 50.0, 'temp_after': 49.0, 'ref_temp_before': 50.0, 'ref_temp_after': 51.0,
    });
    expect(m.netNdvi, closeTo(0.07, 1e-9));
    expect(m.netTemp, closeTo(-2.0, 1e-9));
    expect(CampaignMeasurement({}).netNdvi, isNull);

    final c = Campaign.fromJson({
      'id': 1, 'name': 'x', 'area_name': 'y', 'lat': 33.0, 'lng': 44.0, 'radius_m': 100,
      'planted_on': '2024-03-01', 'trees_planted': 100, 'trees_alive': 80, 'condition': 'needs_care',
    });
    expect(c.successRate, 0.8);
    expect(c.condition, TreeCondition.needsCare);
  });

  group('اقتراح الأشجار', () {
    Area site(double built, double water, double soil) =>
        Area(id: 1, name: 'x', builtUpRatio: built, waterDistanceM: water, soilWater: soil);
    List<String> names(Area a) => suggestTrees(a).map((s) => s.species.scientificName).toList();

    test('لا اقتراحات دون بيانات الموقع', () {
      expect(suggestTrees(Area(id: 1, name: 'x')), isEmpty);
    });

    test('البناء الكثيف يستبعد الأشجار ذات الجذور المضرة', () {
      final suggested = suggestTrees(site(0.5, 1500, 0.5));
      expect(suggested, hasLength(3));
      expect(suggested.every((s) => s.species.safeNearBuildings), isTrue);
    });

    test('شجر الضفاف لا يُقترح بعيداً عن المياه', () {
      expect(names(site(0.1, 1500, 0.5)), isNot(contains('Populus euphratica')));
    });

    test('الأرض المفتوحة البعيدة عن المياه تفضّل قليل الحاجة إلى الماء', () {
      final suggested = suggestTrees(site(0.1, 4500, 0.5));
      expect(suggested.first.species.water, WaterNeed.low);
    });
  });

  test('تدرج الغطاء النباتي من الأحمر الغامق إلى الأخضر', () {
    const stops = ZillColors.coverageStops;
    expect(coverageColorOf(-0.2), stops.first.$2);
    expect(coverageColorOf(0.0), stops.first.$2);
    expect(coverageColorOf(0.9), stops.last.$2);
    expect(coverageColorOf(null), ZillColors.noData);
  });

  test('القائمة مرتبة من الأقل تشجيراً، والمناطق بلا بيانات في النهاية', () {
    final store = AreasStore()
      ..areas = [
        Area(id: 1, name: 'أ', ndvi: 0.4),
        Area(id: 2, name: 'ب'),
        Area(id: 3, name: 'ج', ndvi: 0.05),
      ];
    expect(store.byVegetation.map((a) => a.id), [3, 1, 2]);
  });

  test('النقاط الخضراء: نقطتان لكل 3 أشجار كاملة، و50 نقطة تحتاج 75 شجرة', () {
    expect(GreenPoints.forTrees(2), 0);
    expect(GreenPoints.forTrees(3), 2);
    expect(GreenPoints.forTrees(7), 4);
    expect(GreenPoints.treesToRedeem, 75);
    expect(GreenPoints.forTrees(GreenPoints.treesToRedeem), GreenPoints.redeemPoints);
  });
}

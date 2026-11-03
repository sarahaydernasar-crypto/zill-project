import 'area.dart';

/// حاجة الشجرة إلى الماء
enum WaterNeed { low, medium, high }

/// نوع شجرة مناسب لمناخ بغداد
class TreeSpecies {
  const TreeSpecies({
    required this.name,
    required this.scientificName,
    required this.water,
    required this.shade,
    required this.safeNearBuildings,
    required this.description,
    this.caution,
  });

  final String name;
  final String scientificName;
  final WaterNeed water;
  final int shade; // 0 قليل، 1 متوسط، 2 كثيف
  final bool safeNearBuildings; // جذوره أقل ضرراً بالأرصفة والأنابيب
  final String description;
  final String? caution;
}

const treeCatalog = <TreeSpecies>[
  TreeSpecies(
    name: 'السدر (النبق)',
    scientificName: 'Ziziphus spina-christi',
    water: WaterNeed.low,
    shade: 1,
    safeNearBuildings: true,
    description: 'شجرة محلية تتحمل الحر والجفاف وتعطي ظلاً جيداً.',
    caution: 'أغصانه شائكة، فيُبعد عن ممرات المشاة الضيقة.',
  ),
  TreeSpecies(
    name: 'نخيل التمر',
    scientificName: 'Phoenix dactylifera',
    water: WaterNeed.medium,
    shade: 0,
    safeNearBuildings: true,
    description: 'شجرة العراق المعروفة، تتحمل الحر والملوحة وجذورها لا ترفع الأرصفة عادةً.',
  ),
  TreeSpecies(
    name: 'الزيتون',
    scientificName: 'Olea europaea',
    water: WaterNeed.low,
    shade: 1,
    safeNearBuildings: true,
    description: 'يتحمل الجفاف بعد أن يثبت، وحجمه مناسب للحدائق والأماكن المحدودة.',
    caution: 'يحتاج إلى تربة جيدة التصريف.',
  ),
  TreeSpecies(
    name: 'اللبخ',
    scientificName: 'Albizia lebbeck',
    water: WaterNeed.medium,
    shade: 2,
    safeNearBuildings: true,
    description: 'ظله عريض، وهو مناسب للشوارع الواسعة والساحات.',
    caution: 'يحتاج إلى مساحة كافية لتمدد تاجه، وأوراقه وقرونه تتساقط.',
  ),
  TreeSpecies(
    name: 'السبحبح (الزنزلخت)',
    scientificName: 'Melia azedarach',
    water: WaterNeed.medium,
    shade: 2,
    safeNearBuildings: true,
    description: 'سريع النمو ويعطي ظلاً كثيفاً، ويتحمل حر الصيف.',
    caution: 'ثماره سامة إذا أُكلت، فيُتجنب قرب مناطق لعب الأطفال.',
  ),
  TreeSpecies(
    name: 'الأثل',
    scientificName: 'Tamarix aphylla',
    water: WaterNeed.low,
    shade: 1,
    safeNearBuildings: false,
    description: 'يتحمل الجفاف والملوحة بدرجة عالية، ومناسب كمصدات رياح في الأراضي المفتوحة.',
    caution: 'جذوره واسعة، فيُبعد عن المباني والأنابيب.',
  ),
  TreeSpecies(
    name: 'الغاف',
    scientificName: 'Prosopis cineraria',
    water: WaterNeed.low,
    shade: 1,
    safeNearBuildings: false,
    description: 'جذوره عميقة ويتحمل الجفاف الشديد، ومناسب للأراضي المفتوحة البعيدة عن المياه.',
    caution: 'نموه بطيء في السنوات الأولى.',
  ),
  TreeSpecies(
    name: 'التوت',
    scientificName: 'Morus alba',
    water: WaterNeed.medium,
    shade: 2,
    safeNearBuildings: false,
    description: 'ظله كثيف وهو شائع في العراق.',
    caution: 'جذوره سطحية، وثماره تتساقط، فيُبعد عن الأرصفة ومواقف السيارات.',
  ),
  TreeSpecies(
    name: 'الحور الفراتي (الغرب)',
    scientificName: 'Populus euphratica',
    water: WaterNeed.high,
    shade: 2,
    safeNearBuildings: false,
    description: 'شجرة محلية على ضفاف دجلة والفرات، وتتحمل الملوحة.',
    caution: 'يناسب الضفاف فقط لأنه يحتاج إلى مياه قريبة، ويُبعد عن المباني.',
  ),
];

/// عتبات خصائص الموقع (متوسطات على مستوى القضاء)
// عتبة منخفضة عمداً: حدود القضاء تشمل أراضي مفتوحة تخفض المتوسط، وخطأ الجذور قرب المباني مكلف
const _denseBuiltUp = 0.25;
const _riversideMeters = 500;
const _nearWaterMeters = 1600;
const _farWaterMeters = 2500;
const _lowSoilWater = 0.4;
const _highSoilWater = 0.7;

/// اقتراح مع سبب مناسبته لهذا القضاء
class TreeSuggestion {
  const TreeSuggestion(this.species, this.reasons);
  final TreeSpecies species;
  final List<String> reasons;
}

/// وصف قصير لخصائص القضاء التي بُني عليها الاقتراح؛ فارغ إذا لم تتوفر البيانات
List<String> siteSummary(Area a) {
  if (!a.hasSiteData) return const [];
  final soil = a.soilWater! < _lowSoilWater
      ? 'ضعيفة'
      : (a.soilWater! < _highSoilWater ? 'متوسطة' : 'جيدة');
  return [
    'المساحة المبنية: ${(a.builtUpRatio! * 100).round()}%',
    'متوسط البعد عن المياه: ${fmt(a.waterDistanceM! / 1000, 1)} كم',
    'قدرة التربة على حفظ الماء: $soil',
  ];
}

/// يرتب الأنواع حسب خصائص القضاء ويعيد أفضلها؛ قائمة فارغة إذا لم تتوفر البيانات
List<TreeSuggestion> suggestTrees(Area a, {int count = 3}) {
  if (!a.hasSiteData) return const [];
  final dense = a.builtUpRatio! >= _denseBuiltUp;
  final near = a.waterDistanceM! <= _nearWaterMeters;
  final far = a.waterDistanceM! >= _farWaterMeters;
  final poorSoil = a.soilWater! < _lowSoilWater;
  final goodSoil = a.soilWater! >= _highSoilWater;

  final scored = <(int, TreeSuggestion)>[];
  for (final t in treeCatalog) {
    // شجر الضفاف لا يُقترح إلا إذا كان القضاء كله قريباً جداً من المياه
    if (t.water == WaterNeed.high && a.waterDistanceM! > _riversideMeters) continue;

    var score = t.shade;
    final why = <String>[];
    if (t.shade == 2) why.add('ظله الكثيف يفيد مع ارتفاع حرارة القضاء');

    if (dense) {
      score += t.safeNearBuildings ? 2 : -3;
      if (t.safeNearBuildings) why.add('مناسب قرب المباني، فالبناء كثيف هنا');
    } else if (!t.safeNearBuildings) {
      score += 1;
      why.add('تتوفر أراضٍ مفتوحة تناسب جذوره');
    }

    if (far) {
      if (t.water == WaterNeed.low) {
        score += 2;
        why.add('يحتاج إلى ماء قليل، والقضاء بعيد نسبياً عن المياه');
      } else {
        score -= 1;
      }
    } else if (near && t.water != WaterNeed.low) {
      score += 1;
      why.add('قرب المياه يسهّل ريّه');
    }

    if (poorSoil && t.water == WaterNeed.low) {
      score += 1;
      why.add('يناسب التربة الضعيفة في حفظ الماء');
    } else if (goodSoil && t.water != WaterNeed.low) {
      score += 1;
      why.add('التربة هنا تحفظ الماء جيداً');
    }

    scored.add((score, TreeSuggestion(t, why)));
  }

  // الفرز ثابت: عند التعادل يبقى ترتيب treeCatalog
  final indexed = scored.indexed.toList()
    ..sort((x, y) {
      final c = y.$2.$1.compareTo(x.$2.$1);
      return c != 0 ? c : x.$1.compareTo(y.$1);
    });
  return [for (final e in indexed.take(count)) e.$2.$2];
}

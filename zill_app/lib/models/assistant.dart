import '../services/areas_store.dart';
import 'area.dart';
import 'campaign.dart';
import 'trees.dart';

/// رد المساعد، مع منطقة أو موقع يمكن فتحه على الخريطة
class AssistantReply {
  const AssistantReply(this.text, {this.areaId, this.siteId});
  final String text;
  final int? areaId;
  final int? siteId;
}

const assistantExamples = [
  'ما أكثر مناطق بغداد حرارة؟',
  'أين توجد أفضل المواقع المقترحة للتشجير؟',
  'ما المناطق التي تحتاج إلى تدخل عاجل؟',
  'لماذا تم اختيار المحمودية؟',
  'ما الأشجار المناسبة للكرخ؟',
];

/// مساعد يجيب من بيانات المنصة فقط: يتعرف على نية السؤال واسم المنطقة،
/// ولا يذكر أي رقم غير موجود في البيانات.
class Assistant {
  Assistant(this.store, this.campaigns);
  final AreasStore store;
  final List<Campaign> campaigns;

  /// توحيد الكتابة العربية حتى تتطابق الصيغ المختلفة للكلمة
  static String normalize(String s) => s
      .replaceAll(RegExp('[ً-ْـ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .toLowerCase();

  static bool _has(String q, List<String> words) => words.any(q.contains);

  /// يبحث عن اسم منطقة في السؤال؛ الاسم الأطول أولاً حتى لا يطغى «الكرخ» على «مركز قضاء الكرخ»
  Area? _findArea(String q) {
    String key(String name) => normalize(name)
        .replaceFirst(RegExp(r'^(ناحيه مركز قضاء|مركز قضاء|ناحيه|قضاء|حي)\s+'), '')
        .trim();
    final all = [...store.areas, ...store.subAreas]
      ..sort((a, b) => key(b.name).length.compareTo(key(a.name).length));
    for (final a in all) {
      final k = key(a.name);
      if (k.length >= 3 && (q.contains(k) || q.contains(k.replaceFirst(RegExp(r'^ال'), '')))) return a;
    }
    return null;
  }

  AssistantReply answer(String question) {
    if (store.areas.isEmpty) {
      return const AssistantReply('لا تتوفر بيانات حالياً. تأكد من تشغيل الخادم ثم أعد المحاولة.');
    }
    final q = normalize(question);
    final area = _findArea(q);

    if (area != null && _has(q, ['شجر', 'اشجار', 'نوع', 'انواع', 'ازرع', 'نزرع'])) return _trees(area);
    if (_has(q, ['لماذا', 'ليش', 'لماذ', 'سبب'])) {
      return area != null
          ? _why(area)
          : const AssistantReply('اذكر اسم المنطقة حتى أوضح سبب اختيارها، مثل: لماذا تم اختيار المحمودية؟');
    }
    if (_has(q, ['عاجل', 'طارئ', 'تدخل', 'اولا'])) return _urgent();
    if (_has(q, ['حمله', 'حملات'])) return _campaigns();
    if (_has(q, ['موقع', 'مواقع', 'اماكن', 'مكان', 'اين', 'وين'])) return _sites(area);
    if (_has(q, ['حراره', 'احر', 'اسخن', 'حار', 'ساخن'])) return _hottest(area);
    if (_has(q, ['غطاء', 'نبات', 'اخضر', 'ndvi', 'تشجيرا', 'تشجير'])) return _leastGreen(area);
    if (area != null) return _summary(area);

    return AssistantReply(
      'لم أفهم السؤال. أجيب عن بيانات المنصة فقط، مثل:\n${assistantExamples.map((e) => '• $e').join('\n')}',
    );
  }

  /// مناطق القضاء إن كان السؤال عن قضاء، وإلا فالأقضية كلها
  List<Area> _scope(Area? area) {
    if (area != null && area.district == null) {
      final subs = store.subAreasOf(area);
      if (subs.isNotEmpty) return subs;
    }
    return store.areas;
  }

  String _line(Area a) =>
      '• ${a.name}: الحرارة ${degWords(a.temperature)}، وNDVI ${fmt(a.ndvi, 2)}';

  AssistantReply _hottest(Area? area) {
    final list = _scope(area).where((a) => a.temperature != null).toList()
      ..sort((a, b) => b.temperature!.compareTo(a.temperature!));
    final where = area != null && area.district == null ? 'في ${area.name}' : 'في بغداد';
    return AssistantReply(
      'أكثر المناطق حرارة $where (متوسط حرارة سطح الأرض صيفاً):\n${list.take(5).map(_line).join('\n')}',
      areaId: list.firstOrNull?.id,
    );
  }

  AssistantReply _leastGreen(Area? area) {
    final list = _scope(area).where((a) => a.ndvi != null).toList()
      ..sort((a, b) => a.ndvi!.compareTo(b.ndvi!));
    return AssistantReply(
      'الأقل غطاءً نباتياً:\n${list.take(5).map(_line).join('\n')}',
      areaId: list.firstOrNull?.id,
    );
  }

  AssistantReply _urgent() {
    final pool = store.subAreas.isNotEmpty ? store.subAreas : store.areas;
    final list = pool
        .where((a) => a.ndvi != null && a.temperature != null && a.ndvi! < 0.2 && a.temperature! >= 50)
        .toList()
      ..sort((a, b) => b.temperature!.compareTo(a.temperature!));
    if (list.isEmpty) return const AssistantReply('لا توجد منطقة تحقق شرطي الأولوية العاجلة في البيانات الحالية.');
    String line(Area a) => '${_line(a)}${a.district == null ? '' : ' (${a.district})'}';
    return AssistantReply(
      'أعدّ المنطقة عاجلة إذا بلغت حرارتها 50 درجة مئوية فأكثر وكان NDVI فيها أقل من 0.2. '
      'هذا معيار من بيانات المنصة وليس تقييماً رسمياً. تحققه ${list.length} منطقة، وأشدها حرارة:\n'
      '${list.take(5).map(line).join('\n')}',
      areaId: list.first.id,
    );
  }

  AssistantReply _sites(Area? area) {
    final sites = (area == null ? store.sites : store.sitesIn(area)).toList()
      ..sort((a, b) => (b.priority ?? 0).compareTo(a.priority ?? 0));
    if (sites.isEmpty) {
      return AssistantReply(area == null
          ? 'لا توجد مواقع مقترحة في البيانات الحالية.'
          : 'لا توجد مواقع مقترحة داخل ${area.name} في البيانات الحالية.');
    }
    final lines = sites.take(5).map((s) =>
        '• ${s.title}${s.place == null ? '' : ' (${s.district})'}: ${fmt(s.areaHa, 1)} هكتار، ودرجة الأولوية ${fmt(s.priority, 0)} من 100');
    return AssistantReply(
      'أعلى المواقع أولوية${area == null ? '' : ' في ${area.name}'}:\n${lines.join('\n')}\n'
      'هذه مواقع محتملة من صور الأقمار الصناعية، وتحتاج إلى معاينة ميدانية والتأكد من ملكيتها.',
      siteId: sites.first.id,
    );
  }

  AssistantReply _why(Area a) => AssistantReply(
        'سبب ظهور ${a.name} في النتائج:\n${a.reasons.map((r) => '• $r').join('\n')}',
        areaId: a.id,
      );

  AssistantReply _trees(Area a) {
    final suggestions = suggestTrees(a);
    if (suggestions.isEmpty) {
      return AssistantReply('لا تتوفر خصائص الموقع اللازمة لاقتراح الأشجار في ${a.name}.');
    }
    final lines = suggestions.map((s) => '• ${s.species.name}: ${s.reasons.isEmpty ? s.species.description : s.reasons.join('، ')}');
    return AssistantReply(
      'الأشجار المقترحة في ${a.name}:\n${lines.join('\n')}\n'
      'هذه مقترحات أولية، ويلزم فحص ملوحة التربة واستشارة مختص زراعي قبل الزراعة.',
      areaId: a.id,
    );
  }

  AssistantReply _campaigns() {
    if (campaigns.isEmpty) return const AssistantReply('لا توجد حملات تشجير مسجلة في المنصة بعد.');
    final planted = campaigns.fold<int>(0, (sum, c) => sum + c.treesPlanted);
    return AssistantReply('سُجلت ${campaigns.length} حملة، زُرعت فيها $planted شجرة. التفاصيل في صفحة الحملات.');
  }

  AssistantReply _summary(Area a) => AssistantReply(
        '${a.name}: حرارة السطح ${degWords(a.temperature)}، وNDVI ${fmt(a.ndvi, 2)}، '
        'ودرجة أولوية التشجير ${fmt(a.priority, 0)} من 100 (${a.priorityLevel.label}).',
        areaId: a.id,
      );
}

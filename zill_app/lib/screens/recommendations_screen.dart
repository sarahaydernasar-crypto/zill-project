import 'package:flutter/material.dart';

import '../models/area.dart';
import '../services/areas_store.dart';
import '../theme.dart';
import '../widgets/area_details.dart';
import '../widgets/common.dart';

/// توصيات التشجير
class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key, required this.onShowOnMap});
  final void Function(int areaId) onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final store = AreasScope.of(context);
    final recos = store.recommendations;
    final hasImpact = recos.any((a) => a.impact != null);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            const Text('توصيات التشجير',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
            const Text('المناطق مرتبة من الأعلى أولوية إلى الأقل، حسب درجة أولوية التشجير (0–100).',
                style: TextStyle(color: ZillColors.muted)),
            const SizedBox(height: 20),
            if (store.status == LoadStatus.error) ...[
              ErrorBanner(message: store.error!, onRetry: store.load),
              const SizedBox(height: 16),
            ],
            if (recos.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      store.status == LoadStatus.loaded
                          ? 'لا توجد مناطق مرشحة للتشجير في البيانات الحالية.'
                          : 'لم يتم تحميل البيانات بعد.',
                      style: const TextStyle(color: ZillColors.muted),
                    ),
                  ),
                ),
              ),
            for (var i = 0; i < recos.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RecoCard(rank: i + 1, area: recos[i], onShowOnMap: onShowOnMap),
              ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration:
                  BoxDecoration(color: ZillColors.greenLight, borderRadius: BorderRadius.circular(14)),
              child: Text.rich(TextSpan(children: [
                const TextSpan(
                    text: 'عن تقدير تأثير التشجير: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                  text: hasImpact
                      ? 'التقديرات المعروضة مأخوذة من بيانات فريق التحليل.'
                      : 'لا نعرض حالياً رقماً لمقدار انخفاض الحرارة المتوقع، لأنه يحتاج إلى بيانات علمية ميدانية خاصة بالمدينة لم تتوفر بعد. سيظهر التقدير هنا عندما يضيفه فريق البيانات.',
                ),
              ])),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoCard extends StatelessWidget {
  const _RecoCard({required this.rank, required this.area, required this.onShowOnMap});
  final int rank;
  final Area area;
  final void Function(int areaId) onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final score = Column(children: [
      Text(fmt(area.priority, 0),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: ZillColors.greenDark, height: 1)),
      const Text('من 100', style: TextStyle(fontSize: 12, color: ZillColors.muted)),
    ]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ZillColors.grayLight,
        borderRadius: BorderRadius.circular(14),
        border: BorderDirectional(start: BorderSide(color: area.color, width: 6)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: ZillColors.greenDark,
          child: Text('$rank',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(area.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
              ),
              if (narrow) score,
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('🌡️ ${deg(area.temperature)}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: ZillColors.muted)),
              Text('🌿 NDVI ${fmt(area.ndvi, 2)}', style: const TextStyle(color: ZillColors.muted)),
              PriorityBadge(area.priorityLevel),
            ]),
            const SizedBox(height: 10),
            ReasonsList(area.reasons),
            if (area.impact != null) ...[
              const SizedBox(height: 6),
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'التأثير المتوقع: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: area.impact),
              ])),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => onShowOnMap(area.id),
              icon: const Icon(Icons.place_outlined, size: 18),
              label: const Text('عرض على الخريطة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZillColors.green,
                side: const BorderSide(color: ZillColors.green, width: 2),
                backgroundColor: Colors.white,
              ),
            ),
          ]),
        ),
        if (!narrow) ...[const SizedBox(width: 16), score],
      ]),
    );
  }
}

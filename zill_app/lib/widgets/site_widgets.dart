import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/area.dart';
import '../models/planting_site.dart';
import '../models/trees.dart';
import '../services/areas_store.dart';
import '../theme.dart';
import 'impact_card.dart';

const _fieldCheckNote =
    'موقع محتمل استُخرج من صور الأقمار الصناعية. قد يكون مملوكاً أو مخصصاً لاستخدام آخر، فيجب معاينته والتأكد من ملكيته قبل الزراعة.';

/// قائمة المواقع المحتملة داخل قضاء
class SiteSuggestions extends StatelessWidget {
  const SiteSuggestions({super.key, required this.area, required this.onTap, this.limit = 3});
  final Area area;
  final void Function(PlantingSite site) onTap;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final sites = AreasScope.of(context).sitesIn(area).take(limit).toList();
    if (sites.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('أماكن مقترحة للتشجير',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ZillColors.greenDark)),
      const SizedBox(height: 2),
      const Text('أراضٍ مكشوفة وسط العمران، وتحتاج إلى معاينة ميدانية.',
          style: TextStyle(fontSize: 13, color: ZillColors.muted)),
      const SizedBox(height: 8),
      for (final (i, s) in sites.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onTap(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.place, size: 20, color: ZillColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.place ?? 'موقع ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${fmt(s.areaHa, 1)} هكتار · درجة الأولوية ${fmt(s.priority, 0)}',
                          style: const TextStyle(fontSize: 13, color: ZillColors.muted)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: ZillColors.muted),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// تفاصيل موقع تشجير
class SiteCard extends StatelessWidget {
  const SiteCard({super.key, required this.site, this.onClose});
  final PlantingSite site;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final area = AreasScope.of(context).areas.where((a) => a.name == site.district).firstOrNull;
    final trees = area == null ? const <TreeSuggestion>[] : suggestTrees(area);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Text(site.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
          ),
          if (onClose != null)
            IconButton(onPressed: onClose, icon: const Icon(Icons.close), tooltip: 'إغلاق'),
        ]),
        Text('قضاء ${site.district}', style: const TextStyle(color: ZillColors.muted)),
        const SizedBox(height: 12),
        _row('المساحة التقريبية', '${fmt(site.areaHa, 1)} هكتار'),
        _row('حرارة السطح', deg(site.temperature), ltr: true),
        _row('مؤشر الغطاء النباتي NDVI', fmt(site.ndvi, 2), ltr: true),
        _row('درجة الأولوية', '${fmt(site.priority, 0)} / 100', ltr: true),
        if (site.waterDistanceM != null)
          _row('البعد عن المياه السطحية', '${fmt(site.waterDistanceM! / 1000, 1)} كم'),
        if (site.areaHa != null) ...[
          const SizedBox(height: 8),
          ImpactCard(areaHa: site.areaHa!),
        ],
        if (trees.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('أشجار مقترحة لهذا القضاء',
              style: TextStyle(fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
          const SizedBox(height: 2),
          Text(trees.map((t) => t.species.name).join('، ')),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
          child: const Text(_fieldCheckNote,
              style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF92400E))),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('https://www.google.com/maps/search/?api=1&query='
                '${site.point.latitude},${site.point.longitude}'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('فتح الموقع في خرائط Google'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ZillColors.green,
            side: const BorderSide(color: ZillColors.green, width: 2),
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool ltr = false}) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: ZillColors.muted))),
          Text(value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}

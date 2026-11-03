import 'package:flutter/material.dart';

import '../models/area.dart';
import '../services/areas_store.dart';
import '../theme.dart';
import 'common.dart';
import 'site_widgets.dart';
import 'tree_suggestions.dart';

/// شاشة/لوحة تفاصيل المنطقة
class AreaDetails extends StatelessWidget {
  const AreaDetails({super.key, required this.area, this.onClose});
  final Area area;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final lvl = area.heatLevel;
    final onColor = lvl == HeatLevel.warm ? ZillColors.text : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Text(area.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
          ),
          if (onClose != null)
            IconButton(onPressed: onClose, icon: const Icon(Icons.close), tooltip: 'إغلاق'),
        ]),
        if (area.district != null)
          Text('${area.level ?? 'منطقة'} في قضاء ${area.district}',
              style: const TextStyle(color: ZillColors.muted)),
        const SizedBox(height: 8),

        // درجة الحرارة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: area.color, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(deg(area.temperature),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w800, color: onColor, height: 1)),
            const SizedBox(width: 10),
            Text('حرارة سطح الأرض', style: TextStyle(color: onColor)),
          ]),
        ),
        const SizedBox(height: 12),

        _row('التصنيف', Text(area.classificationAr, style: _bold)),
        _row('مؤشر الغطاء النباتي NDVI', Text(fmt(area.ndvi, 2), style: _bold)),
        _row('أولوية التشجير', PriorityBadge(area.priorityLevel)),

        if (area.priority != null) ...[
          const SizedBox(height: 6),
          Text('درجة الأولوية: ${fmt(area.priority, 0)} / 100',
              style: const TextStyle(fontSize: 13, color: ZillColors.muted)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (area.priority! / 100).clamp(0, 1),
              minHeight: 8,
              color: ZillColors.green,
              backgroundColor: const Color(0xFFE5E7EB),
            ),
          ),
        ],

        const SizedBox(height: 16),
        const Text('لماذا هذه المنطقة؟',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ZillColors.greenDark)),
        const SizedBox(height: 6),
        ReasonsList(area.reasons),
        const SizedBox(height: 16),
        TreeSuggestions(area: area),
        const SizedBox(height: 16),
        SiteSuggestions(
          area: area,
          limit: 8,
          onTap: (site) {
            final store = AreasScope.of(context);
            Navigator.of(context).maybePop();
            store.selectSite(site.id);
          },
        ),

        if (area.impact != null) ...[
          const SizedBox(height: 16),
          const Text('تأثير التشجير المتوقع',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ZillColors.greenDark)),
          Text(area.impact!),
        ],
      ],
    );
  }

  static const _bold = TextStyle(fontWeight: FontWeight.bold);

  Widget _row(String label, Widget value) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: ZillColors.muted))),
          value,
        ]),
      );
}

class ReasonsList extends StatelessWidget {
  const ReasonsList(this.reasons, {super.key});
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 8),
                child: Icon(Icons.circle, size: 6, color: ZillColors.green),
              ),
              Expanded(child: Text(r)),
            ]),
          ),
      ],
    );
  }
}

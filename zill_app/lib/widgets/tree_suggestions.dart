import 'package:flutter/material.dart';

import '../models/area.dart';
import '../models/trees.dart';
import '../theme.dart';

/// الأشجار المقترحة لقضاء معين، مع أسباب الاختيار وتحذيراته
class TreeSuggestions extends StatelessWidget {
  const TreeSuggestions({super.key, required this.area});
  final Area area;

  @override
  Widget build(BuildContext context) {
    final suggestions = suggestTrees(area);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('الأشجار المقترحة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ZillColors.greenDark)),
      const SizedBox(height: 6),
      if (suggestions.isEmpty)
        const Text('ستظهر الاقتراحات بعد تحديث بيانات القضاء.',
            style: TextStyle(color: ZillColors.muted))
      else ...[
        Text(siteSummary(area).join(' · '),
            style: const TextStyle(fontSize: 13, color: ZillColors.muted, height: 1.5)),
        const SizedBox(height: 8),
        for (final s in suggestions) _TreeCard(suggestion: s),
        const Text(
          'مقترحات أولية مبنية على متوسطات القضاء. تأكدوا من ملوحة التربة وتوفر الري في موقع الزراعة، واستشيروا مختصاً زراعياً قبل التنفيذ. وعلى ضفاف دجلة تحديداً يناسب الحور الفراتي (الغرب). ويُتجنب الكونوكاربس قرب الأنابيب والأرصفة بسبب جذوره، والكالبتوس حيث يقل الماء لأنه كثير الاستهلاك له.',
          style: TextStyle(fontSize: 12, color: ZillColors.muted, height: 1.6),
        ),
      ],
    ]);
  }
}

class _TreeCard extends StatelessWidget {
  const _TreeCard({required this.suggestion});
  final TreeSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final t = suggestion.species;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.park, size: 20, color: ZillColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t.name,
                style: const TextStyle(fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
          ),
        ]),
        Text(t.scientificName,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: ZillColors.muted)),
        const SizedBox(height: 4),
        Text(t.description, style: const TextStyle(fontSize: 13, height: 1.5)),
        if (suggestion.reasons.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('لماذا هنا: ${suggestion.reasons.join('، ')}.',
              style: const TextStyle(fontSize: 13, height: 1.5, color: ZillColors.greenDark)),
        ],
        if (t.caution != null) ...[
          const SizedBox(height: 4),
          Text('تنبيه: ${t.caution}',
              style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFFB45309))),
        ],
      ]),
    );
  }
}

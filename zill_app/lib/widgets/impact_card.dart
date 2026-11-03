import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/area.dart';
import '../models/impact.dart';
import '../theme.dart';

/// التأثير المتوقع لتشجير موقع: نطاقات تقديرية، مع افتراضاتها ومصادرها
class ImpactCard extends StatelessWidget {
  const ImpactCard({super.key, required this.areaHa});
  final double areaHa;

  @override
  Widget build(BuildContext context) {
    final i = SiteImpact(areaHa);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('التأثير المتوقع (تقدير)',
            style: TextStyle(fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        const Text('نطاقات مبنية على افتراضات، وليست نتائج مضمونة.',
            style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
        const SizedBox(height: 8),
        _row('المساحة المتاحة', '${fmt(areaHa, 1)} هكتار'),
        _row('عدد الأشجار', 'من ${i.treesLow} إلى ${i.treesHigh} شجرة'),
        _row('الغطاء الشجري بعد النضج', 'من ${fmt(i.canopyHaLow, 1)} إلى ${fmt(i.canopyHaHigh, 1)} هكتار، أي بين '
            '${(ImpactAssumptions.canopyShareLow * 100).round()}% و${(ImpactAssumptions.canopyShareHigh * 100).round()}% من الموقع'),
        _row('حرارة الهواء داخل الموقع بعد النضج',
            'أبرد بنحو ${fmt(ImpactAssumptions.coolingLowC, 0)} إلى ${fmt(ImpactAssumptions.coolingHighC, 1)} درجة مئوية'),
        _row('امتصاص الكربون بعد النضج',
            'من ${fmt(i.co2TonsPerYearLow, 0)} إلى ${fmt(i.co2TonsPerYearHigh, 0)} طن CO₂ سنوياً'),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          shape: const Border(),
          title: const Text('كيف حسبنا هذا؟', style: TextStyle(fontSize: 13, color: ZillColors.green)),
          children: [
            const Text(
              '• عدد الأشجار: افتراض تخطيطي لتباعد بين 6 و10 أمتار.\n'
              '• الغطاء الشجري: افتراض أن تغطي التيجان بين 30% و60% من الموقع.\n'
              '• الحرارة: متوسطات منشورة للحدائق والغابات الحضرية، ومعظم دراساتها من مناخات أخرى. الأثر في موقع صغير قد يكون أقل، وقد يختلف كثيراً في مناخ بغداد.\n'
              '• الكربون: معدل منشور لكل متر مربع من الظلة في مدن الولايات المتحدة، وليس خاصاً بالعراق أو بنوع الشجرة.\n'
              '• لا يشمل التقدير ماء الري، ولا موت بعض الأشجار، والسنوات اللازمة حتى النضج.',
              style: TextStyle(fontSize: 12, height: 1.7, color: ZillColors.muted),
            ),
            for (final (title, url) in ImpactAssumptions.sources)
              TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 30), foregroundColor: ZillColors.green),
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: Text(title, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: ZillColors.muted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      );
}

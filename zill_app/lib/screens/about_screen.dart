import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme.dart';

/// معلومات المشروع
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            const Text('عن مشروع ظِلّ',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
            const SizedBox(height: 16),
            const _Block(
              icon: Icons.local_fire_department_outlined,
              title: 'المشكلة',
              children: [
                Text('تمتص الأسطح الإسمنتية والأسفلت ومناطق التربة المكشوفة أشعة الشمس، فتصبح المدن أسخن بكثير من محيطها. تسمى هذه الظاهرة «الجزر الحرارية الحضرية». وفي صيف بغداد قد تتجاوز حرارة سطح الأرض 50 درجة مئوية، وهذا يؤثر على صحة السكان ويزيد استهلاك الكهرباء.'),
              ],
            ),
            const _Block(
              icon: Icons.flag_outlined,
              title: 'هدف ظِلّ',
              children: [
                Text('نساعد المواطنين وموظفي البلدية على معرفة المناطق الأشد حرارة والأقل خضرة، ونقترح أين يكون للتشجير أكبر أثر، حتى يكون القرار مبنياً على بيانات.'),
              ],
            ),
            const _Block(
              icon: Icons.satellite_alt_outlined,
              title: 'مصادر البيانات',
              children: [
                _Bullet('Landsat 9 Collection 2 Level 2', 'لحساب درجة حرارة سطح الأرض ومؤشر الغطاء النباتي NDVI (صيف 2026).'),
                _Bullet('Dynamic World', 'لتصنيف استخدام الأرض واستبعاد المناطق المبنية.'),
                _Bullet('JRC Global Surface Water', 'لقياس القرب من المياه السطحية.'),
                _Bullet('OpenLandMap', 'لقدرة التربة على حفظ الماء.'),
                _Bullet('FAO GAUL', 'لحدود أقضية بغداد.'),
                _Bullet('OpenStreetMap', 'لعرض الخريطة.'),
              ],
            ),
            _Block(
              icon: Icons.calculate_outlined,
              title: 'طريقة التحليل',
              children: [
                const _Bullet(null, 'نحذف الغيوم وظلالها من الصور، ثم نأخذ وسيط (median) حرارة الصيف لكل نقطة.'),
                const _Bullet(null, 'نصنّف الحرارة إلى: أقل من 40 درجة مئوية، ومن 40 إلى 50 درجة، وأعلى من 50 درجة.'),
                const _Bullet(null, 'تكون المنطقة مرشحة للتشجير عندما تبلغ حرارتها 45 درجة مئوية أو أكثر ويكون NDVI فيها أقل من 0.2، بشرط ألا تكون منطقة مبنية.'),
                const _Bullet(null, 'درجة الأولوية (0–100) تجمع بين شدة الحرارة والقرب من المياه وقدرة التربة على حفظ الماء.'),
                const SizedBox(height: 6),
                const Text('ملاحظة: درجة الأولوية مؤشر أولي للملاءمة، وليست احتمالاً مقاساً لنجاح الزراعة.',
                    style: TextStyle(fontSize: 13, color: ZillColors.muted)),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(AppConfig.apiBase + AppConfig.analysisMapPath),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('عرض خريطة التحليل التفصيلية'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZillColors.green,
                      side: const BorderSide(color: ZillColors.green, width: 2),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle.merge(
            style: const TextStyle(height: 1.7),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: ZillColors.green),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
              ]),
              const SizedBox(height: 8),
              ...children,
            ]),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.title, this.text);
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 10, left: 8),
          child: Icon(Icons.circle, size: 6, color: ZillColors.green),
        ),
        Expanded(
          child: Text.rich(TextSpan(children: [
            if (title != null)
              TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: text),
          ])),
        ),
      ]),
    );
  }
}

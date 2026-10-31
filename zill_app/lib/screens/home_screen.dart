import 'package:flutter/material.dart';

import '../services/areas_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// الصفحة الرئيسية
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onExploreMap});
  final VoidCallback onExploreMap;

  @override
  Widget build(BuildContext context) {
    final store = AreasScope.of(context);

    return SingleChildScrollView(
      child: Column(children: [
        // ===== الواجهة الترحيبية =====
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 72),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [ZillColors.greenDark, Color(0xFF166534), ZillColors.green],
            ),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const ZillLogo(size: 80),
            ),
            const SizedBox(height: 12),
            const Text('ظِلّ',
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3)),
            const Text(
              'نفهم حرارة مدينتنا، ونزرع لمستقبل أبرد',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: ZillColors.greenLight),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onExploreMap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ZillColors.greenDark,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('استكشف الخريطة'),
            ),
          ]),
        ),

        // ===== نبذة عن الفكرة =====
        Transform.translate(
          offset: const Offset(0, -40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  LayoutBuilder(builder: (context, c) {
                    const cards = [
                      _IntroCard(
                        icon: Icons.satellite_alt_outlined,
                        title: 'نقيس الحرارة من الفضاء',
                        body: 'نحلل صور القمر الصناعي Landsat 9 لمعرفة درجة حرارة سطح الأرض في كل منطقة من المدينة.',
                      ),
                      _IntroCard(
                        icon: Icons.thermostat,
                        title: 'نحدد المناطق الأسخن',
                        body: 'نلوّن الخريطة حسب الحرارة، ونكشف المناطق التي تعاني من ضعف الغطاء النباتي.',
                      ),
                      _IntroCard(
                        icon: Icons.park_outlined,
                        title: 'نقترح أين نزرع',
                        body: 'نرتب المناطق حسب أولوية التشجير، مع مراعاة قرب المياه وقدرة التربة على حفظ الماء.',
                      ),
                    ];
                    if (c.maxWidth < 700) {
                      return Column(children: [
                        for (final card in cards)
                          Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
                      ]);
                    }
                    return IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(child: cards[i]),
                        ],
                      ]),
                    );
                  }),
                  if (store.areas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: ZillColors.greenLight, borderRadius: BorderRadius.circular(14)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('نظرة سريعة على البيانات الحالية',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
                        const SizedBox(height: 12),
                        StatsGrid(store: store, cardBackground: Colors.white),
                      ]),
                    ),
                  ],
                  if (store.status == LoadStatus.error) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: store.error!, onRetry: store.load),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x1414532D), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: ZillColors.greenLight,
          child: Icon(icon, color: ZillColors.green, size: 28),
        ),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(height: 1.6)),
      ]),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models/area.dart';
import '../services/areas_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _maxContentWidth = 1120.0;
const _wideBreakpoint = 820.0;

/// الصفحة الرئيسية
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onExploreMap,
    required this.onRecommendations,
    required this.onShowOnMap,
  });

  final VoidCallback onExploreMap;
  final VoidCallback onRecommendations;
  final void Function(int areaId) onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final store = AreasScope.of(context);
    final lowest = store.byVegetation.where((a) => a.ndvi != null).take(3).toList();

    return SingleChildScrollView(
      child: Column(children: [
        _Hero(store: store, onExploreMap: onExploreMap, onRecommendations: onRecommendations),
        if (store.status == LoadStatus.error)
          _Section(
            bottom: 0,
            child: ErrorBanner(message: store.error!, onRetry: store.load),
          ),
        if (store.areas.isNotEmpty) _Section(child: _KeyFigures(store: store)),
        if (lowest.isNotEmpty)
          _Section(
            top: 0,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(
                title: 'الأقل غطاءً نباتياً',
                subtitle: 'الأقضية ذات أقل قيم NDVI، بحسب نتائج التحليل الحالية.',
              ),
              const SizedBox(height: 16),
              _ResponsiveRow(children: [
                for (final (i, a) in lowest.indexed)
                  _LowestCard(rank: i + 1, area: a, onTap: () => onShowOnMap(a.id)),
              ]),
            ]),
          ),
        const ColoredBox(
          color: ZillColors.grayLight,
          child: _Section(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionTitle(
                title: 'كيف يعمل ظِلّ',
                subtitle: 'من صور الأقمار الصناعية إلى توصية واضحة بمكان الزراعة.',
              ),
              SizedBox(height: 16),
              _ResponsiveRow(children: [
                _StepCard(
                  number: 1,
                  icon: Icons.satellite_alt_outlined,
                  title: 'نقيس من الفضاء',
                  body: 'نحلل صور Landsat 9 لحساب حرارة سطح الأرض ومؤشر الغطاء النباتي NDVI.',
                ),
                _StepCard(
                  number: 2,
                  icon: Icons.layers_outlined,
                  title: 'نقارن بين الأقضية',
                  body: 'نلوّن كل قضاء من الأحمر الغامق للغطاء القليل إلى الأخضر للغطاء الكثيف.',
                ),
                _StepCard(
                  number: 3,
                  icon: Icons.park_outlined,
                  title: 'نقترح أين نزرع',
                  body: 'نرتب الأولويات بحسب شدة الحرارة وقرب المياه وقدرة التربة على حفظ الماء.',
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// يوسّط المحتوى بعرض أقصى ثابت
class _Section extends StatelessWidget {
  const _Section({required this.child, this.top = 32, this.bottom = 32});
  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, top, 20, bottom),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ZillColors.greenDark)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: ZillColors.muted, height: 1.5)),
    ]);
  }
}

/// صف على الشاشات الكبيرة، وعمود على الموبايل
class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 700) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            child,
          ],
        ]);
      }
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: child),
          ],
        ]),
      );
    });
  }
}

// ---------- الواجهة الترحيبية ----------
class _Hero extends StatelessWidget {
  const _Hero({required this.store, required this.onExploreMap, required this.onRecommendations});
  final AreasStore store;
  final VoidCallback onExploreMap;
  final VoidCallback onRecommendations;

  @override
  Widget build(BuildContext context) {
    final text = _HeroText(onExploreMap: onExploreMap, onRecommendations: onRecommendations);
    final preview = _DistrictsPreview(store: store, onTap: onExploreMap);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [ZillColors.greenDark, Color(0xFF166534)],
        ),
      ),
      child: _Section(
        top: 48,
        bottom: 48,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < _wideBreakpoint) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              text,
              const SizedBox(height: 32),
              SizedBox(height: 300, child: preview),
            ]);
          }
          return SizedBox(
            height: 400,
            child: Row(children: [
              Expanded(flex: 11, child: text),
              const SizedBox(width: 40),
              Expanded(flex: 10, child: preview),
            ]),
          );
        }),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.onExploreMap, required this.onRecommendations});
  final VoidCallback onExploreMap;
  final VoidCallback onRecommendations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('خريطة حرارة بغداد وغطائها النباتي',
            style: TextStyle(color: ZillColors.greenLight, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        const Text(
          'نفهم حرارة مدينتنا، ونزرع لمستقبل أبرد',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ظِلّ يحوّل صور الأقمار الصناعية إلى خريطة واضحة تبيّن أين ترتفع الحرارة ويقل الغطاء النباتي، ليكون قرار التشجير مبنياً على بيانات.',
          style: TextStyle(color: Color(0xFFE5F5EA), fontSize: 17, height: 1.7),
        ),
        const SizedBox(height: 28),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton.icon(
            onPressed: onExploreMap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ZillColors.greenDark,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.map_outlined),
            label: const Text('استكشف الخريطة'),
          ),
          OutlinedButton.icon(
            onPressed: onRecommendations,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.park_outlined),
            label: const Text('توصيات التشجير'),
          ),
        ]),
      ],
    );
  }
}

/// معاينة حدود الأقضية الحقيقية بألوان الغطاء النباتي؛ الضغط عليها يفتح الخريطة
class _DistrictsPreview extends StatelessWidget {
  const _DistrictsPreview({required this.store, required this.onTap});
  final AreasStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shaped = store.areas.where((a) => a.polygons.isNotEmpty).toList();

    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: shaped.isEmpty
                  ? Center(
                      child: Text(
                        store.status == LoadStatus.loading || store.status == LoadStatus.idle
                            ? 'جارٍ تحميل البيانات…'
                            : 'معاينة الخريطة غير متوفرة حالياً',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : CustomPaint(painter: _DistrictsPainter(shaped)),
            ),
            const SizedBox(height: 14),
            const _PreviewLegend(),
          ]),
        ),
      ),
    );
  }
}

class _PreviewLegend extends StatelessWidget {
  const _PreviewLegend();

  @override
  Widget build(BuildContext context) {
    const stops = ZillColors.coverageStops;
    final max = stops.last.$1;
    const style = TextStyle(color: Colors.white, fontSize: 12);
    return Row(children: [
      const Text('غطاء قليل', style: style),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [for (final s in stops) s.$2],
              stops: [for (final s in stops) s.$1 / max],
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      const Text('غطاء كثيف', style: style),
    ]);
  }
}

class _DistrictsPainter extends CustomPainter {
  _DistrictsPainter(this.areas);
  final List<Area> areas;

  @override
  void paint(Canvas canvas, Size size) {
    final points = areas.expand((a) => a.polygons).expand((p) => p);
    final minLat = points.map((p) => p.latitude).reduce(math.min);
    final maxLat = points.map((p) => p.latitude).reduce(math.max);
    final minLng = points.map((p) => p.longitude).reduce(math.min);
    final maxLng = points.map((p) => p.longitude).reduce(math.max);

    // تصحيح تقارب خطوط الطول حتى لا يتمدد شكل المدينة
    final lngScale = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = (maxLng - minLng) * lngScale;
    final h = maxLat - minLat;
    if (w <= 0 || h <= 0) return;
    final scale = math.min(size.width / w, size.height / h);
    final dx = (size.width - w * scale) / 2;
    final dy = (size.height - h * scale) / 2;

    Offset project(LatLng p) => Offset(
          dx + (p.longitude - minLng) * lngScale * scale,
          dy + (maxLat - p.latitude) * scale,
        );

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;

    for (final a in areas) {
      final fill = Paint()..color = a.coverageColor;
      for (final ring in a.polygons) {
        final path = Path()..addPolygon(ring.map(project).toList(), true);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, border);
      }
    }
  }

  @override
  bool shouldRepaint(_DistrictsPainter old) => old.areas != areas;
}

// ---------- الأرقام الرئيسية ----------
class _KeyFigures extends StatelessWidget {
  const _KeyFigures({required this.store});
  final AreasStore store;

  @override
  Widget build(BuildContext context) {
    final figures = [
      _Figure(value: '${store.areas.length}', label: 'أقضية محللة'),
      _Figure(value: deg(store.maxTemp), label: 'أعلى متوسط لحرارة السطح'),
      _Figure(value: deg(store.avgTemp), label: 'متوسط حرارة السطح'),
      _Figure(value: '${store.lowCoverageCount}', label: 'أقضية بغطاء نباتي ضعيف'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 560 ? 2 : 4;
      final w = (c.maxWidth - (cols - 1) * 24) / cols;
      return Wrap(
        spacing: 24,
        runSpacing: 20,
        children: [for (final f in figures) SizedBox(width: w, child: f)],
      );
    });
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
              fontSize: 36, fontWeight: FontWeight.w800, color: ZillColors.greenDark, height: 1.2)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: ZillColors.muted, fontSize: 14, height: 1.4)),
    ]);
  }
}

// ---------- الأقل غطاءً نباتياً ----------
class _LowestCard extends StatelessWidget {
  const _LowestCard({required this.rank, required this.area, required this.onTap});
  final int rank;
  final Area area;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: area.coverageColor,
                child: Text('$rank',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(area.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
              ),
              const Icon(Icons.chevron_right, color: ZillColors.muted),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Value(value: fmt(area.ndvi, 2), label: 'مؤشر NDVI')),
              Expanded(child: _Value(value: deg(area.temperature), label: 'حرارة السطح')),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(fontSize: 13, color: ZillColors.muted)),
    ]);
  }
}

// ---------- كيف يعمل ----------
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });
  final int number;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: ZillColors.green, size: 28),
          const Spacer(),
          Text('$number',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFD1D5DB))),
        ]),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(height: 1.6)),
      ]),
    );
  }
}

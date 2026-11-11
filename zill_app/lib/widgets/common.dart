import 'package:flutter/material.dart';

import '../config.dart';
import '../models/area.dart';
import '../services/areas_store.dart';
import '../theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.accent = ZillColors.green,
    this.background = ZillColors.grayLight,
  });

  final String value;
  final String label;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(start: BorderSide(color: accent, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accent == ZillColors.green ? ZillColors.greenDark : accent,
              )),
          Text(label, style: const TextStyle(fontSize: 13, color: ZillColors.muted)),
        ],
      ),
    );
  }
}

/// شبكة الإحصائيات (تتكيف مع عرض الشاشة)
class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.store, this.cardBackground = ZillColors.grayLight});
  final AreasStore store;
  final Color cardBackground;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(value: '${store.areas.length}', label: 'منطقة محللة', background: cardBackground),
      StatCard(
          value: '${store.hotCount}',
          label: 'منطقة حارة (${fmt(AppConfig.hotTemp, 0)} درجة فأكثر)',
          accent: ZillColors.heatExtreme,
          background: cardBackground),
      StatCard(
          value: '${store.needPlantingCount}',
          label: 'تحتاج إلى تشجير',
          accent: ZillColors.heatHot,
          background: cardBackground),
      StatCard(
          value: deg(store.maxTemp),
          label: 'أعلى حرارة سطح',
          background: cardBackground),
      StatCard(
          value: deg(store.avgTemp),
          label: 'متوسط الحرارة',
          background: cardBackground),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 5 : (c.maxWidth > 560 ? 3 : 2);
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final card in cards) SizedBox(width: w, child: card)],
      );
    });
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.level, {super.key});
  final PriorityLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(color: level.background, borderRadius: BorderRadius.circular(999)),
      child: Text(level.label,
          style: TextStyle(color: level.foreground, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

/// مفتاح الألوان
class CoverageLegend extends StatelessWidget {
  const CoverageLegend({super.key});

  @override
  Widget build(BuildContext context) {
    const stops = ZillColors.coverageStops;
    final max = stops.last.$1;
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الغطاء النباتي (NDVI)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          // من اليمين: الأقل غطاءً، إلى اليسار: الأكثر
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [for (final s in stops) s.$2],
                stops: [for (final s in stops) s.$1 / max],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('قليل ${fmt(stops.first.$1, 0)}', style: const TextStyle(fontSize: 12)),
            Text('كثيف ${fmt(max, 1)} فأكثر', style: const TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          const Row(children: [
            Icon(Icons.place, size: 16, color: ZillColors.greenDark),
            SizedBox(width: 4),
            Text('موقع تشجير محتمل', style: TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 2),
          const Row(children: [
            Icon(Icons.forest, size: 16, color: Color(0xFF1D4ED8)),
            SizedBox(width: 4),
            Text('حملة منفذة', style: TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 2),
          const Row(children: [
            Icon(Icons.park, size: 16, color: ZillColors.green),
            SizedBox(width: 4),
            Text('شجرة مسجلة', style: TextStyle(fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

/// رسالة خطأ مع زر إعادة المحاولة
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF991B1B),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.cloud_off, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: ZillColors.text),
            child: const Text('إعادة المحاولة'),
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/area.dart';
import '../services/areas_store.dart';
import '../theme.dart';

/// شعار ظِلّ (شجرة داخل دائرة)
class ZillLogo extends StatelessWidget {
  const ZillLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: ZillColors.greenLight, shape: BoxShape.circle),
      child: Icon(Icons.park_rounded, color: ZillColors.green, size: size * 0.62),
    );
  }
}

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
class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text('درجة حرارة سطح الأرض',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          for (final l in HeatLevel.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 18,
                  height: 12,
                  decoration:
                      BoxDecoration(color: l.color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Text(l.label, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(l.range,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 12, color: ZillColors.muted)),
              ]),
            ),
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

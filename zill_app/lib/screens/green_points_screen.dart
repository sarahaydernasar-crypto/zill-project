import 'package:flutter/material.dart';

import '../models/green_points.dart';
import '../theme.dart';

/// شرح النقاط الخضراء لمن ينوي الزراعة
class GreenPointsScreen extends StatelessWidget {
  const GreenPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: [
            const Row(children: [
              Icon(Icons.eco, color: ZillColors.green, size: 32),
              SizedBox(width: 8),
              Expanded(
                child: Text('النقاط الخضراء',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
              ),
            ]),
            const SizedBox(height: 8),
            const Text('قبل أن تزرع، تعرّف على طريقة جمع النقاط وما يمكنك الحصول عليه مقابلها.',
                style: TextStyle(height: 1.6)),
            const SizedBox(height: 16),
            const _NoticeCard(),
            const SizedBox(height: 16),
            const _Section(
              icon: Icons.format_list_numbered,
              title: 'كيف تحصل على النقاط',
              children: [
                _Step(1, 'اختر مكان الزراعة من الخريطة أو التوصيات.'),
                _Step(2, 'ازرع الأشجار وصوّرها بعد الزراعة.'),
                _Step(3, 'سجّل الأشجار وموقعها في المنصة.'),
                _Step(4, 'يراجع المشرف التسجيل، وبعد اعتماده تُضاف النقاط إلى رصيدك.'),
              ],
            ),
            _Section(
              icon: Icons.stars_outlined,
              title: 'قيمة كل مساهمة',
              children: [
                for (final way in GreenPoints.earnWays) _EarnRow(way.title, way.detail, way.points),
              ],
            ),
            const _Section(
              icon: Icons.redeem_outlined,
              title: 'ماذا تفعل بـ ${GreenPoints.redeemPoints} نقطة؟',
              children: [
                _RewardRow(Icons.phone_android, 'تحويلها إلى رصيد آسياسيل'),
                _RewardRow(Icons.storefront_outlined, 'الحصول على خصم من متجر مشارك'),
              ],
            ),
            Text(
              'مثال: إذا جمعت نقاطك من الزراعة وحدها، تصل إلى ${GreenPoints.redeemPoints} نقطة '
              'بعد ${GreenPoints.treesToRedeem} شجرة معتمدة.',
              style: const TextStyle(height: 1.6, color: ZillColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZillColors.greenLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: ZillColors.greenDark),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'النظام قيد الإعداد: القيم أمثلة أولية، ولا يمكن حالياً جمع النقاط أو استبدالها.',
            style: TextStyle(height: 1.6, color: ZillColors.greenDark),
          ),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: ZillColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
              ),
            ]),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: ZillColors.green,
          foregroundColor: Colors.white,
          child: Text('$number', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.6))),
      ]),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow(this.title, this.detail, this.points);
  final String title;
  final String detail;
  final int points;

  String get _pointsLabel => switch (points) {
        1 => 'نقطة',
        2 => 'نقطتان',
        _ => '$points نقاط',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(detail, style: const TextStyle(fontSize: 13, color: ZillColors.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ZillColors.greenLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_pointsLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, color: ZillColors.greenDark)),
        ),
      ]),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: ZillColors.green, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

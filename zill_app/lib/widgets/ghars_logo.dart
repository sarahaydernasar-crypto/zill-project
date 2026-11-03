import 'package:flutter/material.dart';

import '../theme.dart';

/// شعار المساعد غَرْس: شتلة تنبت من أصيص مبتسم.
/// مرسوم بالكود حتى يبقى واضحاً في كل الأحجام.
class GharsLogo extends StatelessWidget {
  const GharsLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'شعار غَرْس',
        child: CustomPaint(size: Size.square(size), painter: const _GharsPainter()),
      );
}

class _GharsPainter extends CustomPainter {
  const _GharsPainter();

  static const _pot = Color(0xFFD97B4A);
  static const _potRim = Color(0xFFC2632F);
  static const _face = Color(0xFF4A2A17);
  static const _cheek = Color(0xFFF2A98A);
  static const _leafLight = Color(0xFF4ADE80);

  @override
  void paint(Canvas canvas, Size size) {
    // كل الإحداثيات على شبكة 100×100
    canvas.scale(size.width / 100, size.height / 100);

    canvas.drawCircle(const Offset(50, 50), 50, Paint()..color = ZillColors.greenLight);

    // الساق
    canvas.drawPath(
      Path()
        ..moveTo(50, 58)
        ..quadraticBezierTo(50, 42, 50, 32),
      Paint()
        ..color = ZillColors.greenDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // الورقتان
    canvas.drawPath(
      Path()
        ..moveTo(50, 36)
        ..cubicTo(44, 18, 26, 14, 16, 20)
        ..cubicTo(18, 34, 34, 44, 50, 36),
      Paint()..color = ZillColors.green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 32)
        ..cubicTo(54, 14, 72, 8, 84, 14)
        ..cubicTo(82, 30, 66, 40, 50, 32),
      Paint()..color = _leafLight,
    );

    // الأصيص
    canvas.drawPath(
      Path()
        ..moveTo(29, 60)
        ..lineTo(71, 60)
        ..lineTo(65, 87)
        ..quadraticBezierTo(64, 91, 60, 91)
        ..lineTo(40, 91)
        ..quadraticBezierTo(36, 91, 35, 87)
        ..close(),
      Paint()..color = _pot,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(25, 52, 50, 11), const Radius.circular(4)),
      Paint()..color = _potRim,
    );

    // الوجه
    final face = Paint()..color = _face;
    canvas.drawCircle(const Offset(42, 72), 3.2, face);
    canvas.drawCircle(const Offset(58, 72), 3.2, face);
    final sparkle = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(43, 71), 1, sparkle);
    canvas.drawCircle(const Offset(59, 71), 1, sparkle);
    canvas.drawCircle(const Offset(36.5, 78), 3, Paint()..color = _cheek);
    canvas.drawCircle(const Offset(63.5, 78), 3, Paint()..color = _cheek);
    canvas.drawPath(
      Path()
        ..moveTo(45, 78)
        ..quadraticBezierTo(50, 83.5, 55, 78),
      Paint()
        ..color = _face
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GharsPainter oldDelegate) => false;
}

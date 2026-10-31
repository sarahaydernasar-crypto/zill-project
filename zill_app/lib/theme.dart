import 'package:flutter/material.dart';

/// ألوان هوية ظِلّ
class ZillColors {
  static const greenDark = Color(0xFF14532D);
  static const green = Color(0xFF16A34A);
  static const greenLight = Color(0xFFDCFCE7);
  static const white = Color(0xFFFFFFFF);
  static const grayLight = Color(0xFFF3F4F6);

  static const heatExtreme = Color(0xFFEF4444);
  static const heatHot = Color(0xFFF97316);
  static const heatWarm = Color(0xFFFACC15);
  static const heatCool = Color(0xFF38BDF8);
  static const noData = Color(0xFF9CA3AF);

  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
}

ThemeData buildZillTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ZillColors.green,
      primary: ZillColors.green,
      secondary: ZillColors.greenDark,
      surface: ZillColors.white,
    ),
    scaffoldBackgroundColor: ZillColors.white,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: ZillColors.greenDark,
      foregroundColor: ZillColors.white,
      centerTitle: true,
      elevation: 0,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: ZillColors.text,
      displayColor: ZillColors.greenDark,
    ),
    cardTheme: CardThemeData(
      color: ZillColors.grayLight,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ZillColors.green,
        foregroundColor: ZillColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ZillColors.white,
      indicatorColor: ZillColors.greenLight,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: ZillColors.white,
      indicatorColor: ZillColors.greenLight,
    ),
  );
}

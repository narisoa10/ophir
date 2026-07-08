import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  //────────────────────────────────────────────────────────
  // BRAND
  //────────────────────────────────────────────────────────

  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryDark = Color(0xFFE85F00);
  static const Color primaryLight = Color(0xFFFFEEE3);

  //────────────────────────────────────────────────────────
  // BACKGROUND
  //────────────────────────────────────────────────────────

  static const Color background = Color(0xFFF8F8F8);
  static const Color backgroundSecondary = Color(0xFFF3F4F6);

  //────────────────────────────────────────────────────────
  // SURFACE
  //────────────────────────────────────────────────────────

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFFAFAFA);
  static const Color surfaceMuted = Color(0xFFF5F5F5);

  static const Color surfaceOrange = Color(0xFFFFF4EC);
  static const Color surfaceGreen = Color(0xFFEFFAF3);
  static const Color surfaceRed = Color(0xFFFFF1F1);
  static const Color surfaceBlue = Color(0xFFEFF6FF);
  static const Color surfacePurple = Color(0xFFF5F0FF);

  //────────────────────────────────────────────────────────
  // TEXT
  //────────────────────────────────────────────────────────

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);
  static const Color textInverse = Color(0xFFFFFFFF);

  //────────────────────────────────────────────────────────
  // ICON
  //────────────────────────────────────────────────────────

  static const Color iconPrimary = Color(0xFF111827);
  static const Color iconSecondary = Color(0xFF6B7280);
  static const Color iconTertiary = Color(0xFF9CA3AF);
  static const Color iconInverse = Color(0xFFFFFFFF);

  //────────────────────────────────────────────────────────
  // BORDER / DIVIDER
  //────────────────────────────────────────────────────────

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderSoft = Color(0xFFF0F0F0);
  static const Color divider = Color(0xFFEDEDED);

  //────────────────────────────────────────────────────────
  // STATUS
  //────────────────────────────────────────────────────────

  static const Color success = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF15803D);
  static const Color successLight = Color(0xFFEAF8EF);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFF7E6);

  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFFEEEE);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoDark = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFEFF6FF);

  //────────────────────────────────────────────────────────
  // FINANCE
  //────────────────────────────────────────────────────────

  static const Color income = success;
  static const Color incomeBackground = successLight;

  static const Color expense = error;
  static const Color expenseBackground = errorLight;

  static const Color balance = primary;
  static const Color balanceBackground = primaryLight;

  static const Color saving = Color(0xFF8B5CF6);
  static const Color savingBackground = Color(0xFFF3EFFF);

  //────────────────────────────────────────────────────────
  // CHARTS
  //────────────────────────────────────────────────────────

  static const Color chartOrange = Color(0xFFFF6B00);
  static const Color chartGreen = Color(0xFF22C55E);
  static const Color chartRed = Color(0xFFEF4444);
  static const Color chartBlue = Color(0xFF3B82F6);
  static const Color chartPurple = Color(0xFF8B5CF6);
  static const Color chartYellow = Color(0xFFFACC15);
  static const Color chartPink = Color(0xFFEC4899);
  static const Color chartCyan = Color(0xFF06B6D4);

  static const List<Color> chartPalette = <Color>[
    chartOrange,
    chartGreen,
    chartBlue,
    chartPurple,
    chartYellow,
    chartPink,
    chartCyan,
    chartRed,
  ];

  //────────────────────────────────────────────────────────
  // OVERLAY / SHADOW
  //────────────────────────────────────────────────────────

  static const Color overlay = Color(0x66000000);
  static const Color shadow = Color(0x1A000000);

  //────────────────────────────────────────────────────────
  // COMMON
  //────────────────────────────────────────────────────────

  static const Color transparent = Colors.transparent;
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
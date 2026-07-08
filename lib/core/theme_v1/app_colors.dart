import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFFEEE3);

  static const Color background = Color(0xFFF8F8F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGreen = Color(0xFFEFFAF3);
  static const Color surfaceRed = Color(0xFFFFF1F1);
  static const Color surfaceBlue = Color(0xFFEFF6FF);
  static const Color surfacePurple = Color(0xFFF5F0FF);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFD1D5DB);
  static const Color textInverse = Color(0xFFFFFFFF);

  static const Color iconPrimary = Color(0xFF111827);
  static const Color iconSecondary = Color(0xFF6B7280);
  static const Color iconTertiary = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color dividerColor = border;
  static const Color progressTrack = Color(0xFFE6E7EB);
  static const Color shadow = Color(0x14000000);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF16A34A);

  static const double financialStateCardBackgroundAlpha = 0.04;
  static const double financialStateCardBorderAlpha = 0.14;
  static const double financialStateProgressBorderAlpha = 0.35;

  static const Color chartGreen = Color(0xFF22C55E);
  static const Color chartRed = Color(0xFFEF4444);
  static const Color chartBlue = Color(0xFF3B82F6);
  static const Color chartPurple = Color(0xFF9333EA);
  static const Color transparent = Color(0x00000000);
}

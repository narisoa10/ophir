import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';

  static const TextStyle _base = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
  );

  static final TextStyle screenTitle = _base.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  static final TextStyle sectionTitle = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static final TextStyle body = _base.copyWith(fontSize: 14, height: 1.45);

  static final TextStyle bodyStrong = body.copyWith(
    fontWeight: FontWeight.w600,
  );

  static final TextStyle caption = _base.copyWith(
    color: AppColors.textSecondary,
    fontSize: 13,
    height: 1.4,
  );

  static final TextStyle captionStrong = caption.copyWith(
    fontWeight: FontWeight.w600,
  );

  static final TextStyle currency = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static final TextStyle currencyStrong = currency.copyWith(
    fontWeight: FontWeight.w600,
  );

  static final TextStyle distributionLabel = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static final TextStyle distributionValue = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static final TextStyle financialStateAmount = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static final TextStyle financialStateMetricLabel = _base.copyWith(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static final TextStyle financialStateDescription = _base.copyWith(
    color: AppColors.textSecondary,
    fontSize: 13,
    height: 1.35,
  );

  static final TextStyle button = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static final TextStyle titleLg = sectionTitle;

  static final TextStyle bodyMd = body;

  static final TextStyle labelSm = caption;

  static final TextStyle buttonMd = button;

  static TextTheme get textTheme => TextTheme(
    headlineLarge: screenTitle,
    titleLarge: sectionTitle,
    titleMedium: bodyStrong,
    titleSmall: bodyStrong,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: captionStrong,
    labelSmall: caption,
  );
}

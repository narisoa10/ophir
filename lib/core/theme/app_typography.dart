import 'package:flutter/material.dart';

abstract final class AppTypography {
  AppTypography._();

  //────────────────────────────────────────────────────────
  // FONT
  //────────────────────────────────────────────────────────

  static const String fontFamily = 'Inter';
  static const Color defaultColor = Color(0xFF111827);

  static const TextStyle _base = TextStyle(
    fontFamily: fontFamily,
    color: defaultColor,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
  );

  //────────────────────────────────────────────────────────
  // DISPLAY
  //────────────────────────────────────────────────────────

  static final TextStyle displayXl = _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.12,
  );

  static final TextStyle displayLg = _base.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  static final TextStyle displayMd = _base.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.18,
  );

  //────────────────────────────────────────────────────────
  // HEADING
  //────────────────────────────────────────────────────────

  static final TextStyle headingLg = _base.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static final TextStyle headingMd = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static final TextStyle headingSm = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  //────────────────────────────────────────────────────────
  // TITLE
  //────────────────────────────────────────────────────────

  static final TextStyle titleLg = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static final TextStyle titleMd = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static final TextStyle titleSm = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  //────────────────────────────────────────────────────────
  // SUBTITLE
  //────────────────────────────────────────────────────────

  static final TextStyle subtitleLg = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static final TextStyle subtitleMd = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static final TextStyle subtitleSm = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  //────────────────────────────────────────────────────────
  // BODY
  //────────────────────────────────────────────────────────

  static final TextStyle bodyLg = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static final TextStyle bodyMd = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static final TextStyle bodySm = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  //────────────────────────────────────────────────────────
  // LABEL
  //────────────────────────────────────────────────────────

  static final TextStyle labelLg = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static final TextStyle labelMd = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static final TextStyle labelSm = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  //────────────────────────────────────────────────────────
  // CAPTION
  //────────────────────────────────────────────────────────

  static final TextStyle captionLg = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static final TextStyle captionMd = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );

  static final TextStyle captionSm = _base.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  //────────────────────────────────────────────────────────
  // NUMBER
  //────────────────────────────────────────────────────────

  static final TextStyle numberXl = _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.4,
  );

  static final TextStyle numberLg = _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.3,
  );

  static final TextStyle numberMd = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.2,
  );

  static final TextStyle numberSm = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.1,
  );

  //────────────────────────────────────────────────────────
  // CURRENCY
  //────────────────────────────────────────────────────────

  static final TextStyle currencyLg = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static final TextStyle currencyMd = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static final TextStyle currencySm = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  //────────────────────────────────────────────────────────
  // PERCENT
  //────────────────────────────────────────────────────────

  static final TextStyle percentLg = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static final TextStyle percentMd = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.1,
  );

  static final TextStyle percentSm = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  //────────────────────────────────────────────────────────
  // BUTTON
  //────────────────────────────────────────────────────────

  static final TextStyle buttonLg = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static final TextStyle buttonMd = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static final TextStyle buttonSm = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  //────────────────────────────────────────────────────────
  // MATERIAL TEXT THEME
  //────────────────────────────────────────────────────────

  static TextTheme get textTheme => TextTheme(
    displayLarge: displayXl,
    displayMedium: displayLg,
    displaySmall: displayMd,
    headlineLarge: headingLg,
    headlineMedium: headingMd,
    headlineSmall: headingSm,
    titleLarge: titleLg,
    titleMedium: titleMd,
    titleSmall: titleSm,
    bodyLarge: bodyLg,
    bodyMedium: bodyMd,
    bodySmall: bodySm,
    labelLarge: buttonLg,
    labelMedium: labelMd,
    labelSmall: captionMd,
  );
}
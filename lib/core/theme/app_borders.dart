import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

abstract final class AppBorders {
  AppBorders._();

  //────────────────────────────────────────────────────────
  // THICKNESS
  //────────────────────────────────────────────────────────

  static const double none = 0;
  static const double thin = 1;
  static const double medium = 1.5;
  static const double thick = 2;

  //────────────────────────────────────────────────────────
  // BORDER SIDES
  //────────────────────────────────────────────────────────

  static const BorderSide transparentSide = BorderSide(
    color: Colors.transparent,
    width: none,
  );

  static const BorderSide defaultSide = BorderSide(
    color: AppColors.border,
    width: thin,
  );

  static const BorderSide softSide = BorderSide(
    color: AppColors.borderSoft,
    width: thin,
  );

  static const BorderSide focusedSide = BorderSide(
    color: AppColors.primary,
    width: medium,
  );

  static const BorderSide successSide = BorderSide(
    color: AppColors.success,
    width: medium,
  );

  static const BorderSide warningSide = BorderSide(
    color: AppColors.warning,
    width: medium,
  );

  static const BorderSide errorSide = BorderSide(
    color: AppColors.error,
    width: medium,
  );

  static const BorderSide disabledSide = BorderSide(
    color: AppColors.borderSoft,
    width: thin,
  );

  //────────────────────────────────────────────────────────
  // OUTLINE INPUT BORDERS
  //────────────────────────────────────────────────────────

  static const OutlineInputBorder input = OutlineInputBorder(
    borderRadius: AppRadius.inputRadius,
    borderSide: defaultSide,
  );

  static const OutlineInputBorder inputFocused = OutlineInputBorder(
    borderRadius: AppRadius.inputRadius,
    borderSide: focusedSide,
  );

  static const OutlineInputBorder inputError = OutlineInputBorder(
    borderRadius: AppRadius.inputRadius,
    borderSide: errorSide,
  );

  static const OutlineInputBorder inputDisabled = OutlineInputBorder(
    borderRadius: AppRadius.inputRadius,
    borderSide: disabledSide,
  );

  static const OutlineInputBorder inputSuccess = OutlineInputBorder(
    borderRadius: AppRadius.inputRadius,
    borderSide: successSide,
  );

  //────────────────────────────────────────────────────────
  // BORDERS
  //────────────────────────────────────────────────────────

  static const Border card = Border.fromBorderSide(
    defaultSide,
  );

  static const Border cardSoft = Border.fromBorderSide(
    softSide,
  );

  static const Border success = Border.fromBorderSide(
    successSide,
  );

  static const Border warning = Border.fromBorderSide(
    warningSide,
  );

  static const Border error = Border.fromBorderSide(
    errorSide,
  );

  //────────────────────────────────────────────────────────
  // DIVIDERS
  //────────────────────────────────────────────────────────

  static const BorderSide divider = BorderSide(
    color: AppColors.divider,
    width: thin,
  );

  static const BorderSide dividerSoft = BorderSide(
    color: AppColors.borderSoft,
    width: thin,
  );

  //────────────────────────────────────────────────────────
  // UNDERLINES
  //────────────────────────────────────────────────────────

  static const Border underline = Border(
    bottom: defaultSide,
  );

  static const Border underlineFocused = Border(
    bottom: focusedSide,
  );

  static const Border underlineError = Border(
    bottom: errorSide,
  );
}
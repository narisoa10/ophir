import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppShadows {
  AppShadows._();

  //────────────────────────────────────────────────────────
  // EXTRA SMALL
  //────────────────────────────────────────────────────────

  static const List<BoxShadow> xs = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  //────────────────────────────────────────────────────────
  // SMALL
  //────────────────────────────────────────────────────────

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  //────────────────────────────────────────────────────────
  // MEDIUM
  //────────────────────────────────────────────────────────

  static const List<BoxShadow> md = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  //────────────────────────────────────────────────────────
  // LARGE
  //────────────────────────────────────────────────────────

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  //────────────────────────────────────────────────────────
  // EXTRA LARGE
  //────────────────────────────────────────────────────────

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  //────────────────────────────────────────────────────────
  // COMPONENTS
  //────────────────────────────────────────────────────────

  static const List<BoxShadow> card = sm;
  static const List<BoxShadow> dialog = lg;
  static const List<BoxShadow> bottomSheet = xl;
  static const List<BoxShadow> floatingButton = md;
}
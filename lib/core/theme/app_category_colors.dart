import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppCategoryColors {
  AppCategoryColors._();

  static const String orange = 'orange';
  static const String green = 'green';
  static const String red = 'red';
  static const String blue = 'blue';
  static const String purple = 'purple';
  static const String yellow = 'yellow';
  static const String cyan = 'cyan';
  static const String gray = 'gray';

  static Color fromKey(String key) {
    return switch (key) {
      orange => AppColors.chartOrange,
      green => AppColors.chartGreen,
      red => AppColors.chartRed,
      blue => AppColors.chartBlue,
      purple => AppColors.chartPurple,
      yellow => AppColors.chartYellow,
      cyan => AppColors.chartCyan,
      gray => AppColors.textSecondary,
      _ => AppColors.primary,
    };
  }

  static Color backgroundFromKey(String key) {
    return switch (key) {
      orange => AppColors.surfaceOrange,
      green => AppColors.surfaceGreen,
      red => AppColors.surfaceRed,
      blue => AppColors.surfaceBlue,
      purple => AppColors.surfacePurple,
      yellow => AppColors.warningLight,
      cyan => AppColors.infoLight,
      gray => AppColors.surfaceMuted,
      _ => AppColors.primaryLight,
    };
  }
}
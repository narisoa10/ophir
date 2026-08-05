import 'package:flutter/material.dart';

import 'app_theme_colors.dart';

abstract final class AppCategoryColors {
  AppCategoryColors._();

  static const String green = 'green';
  static const String red = 'red';
  static const String blue = 'blue';
  static const String purple = 'purple';
  static const String orange = 'orange';
  static const String cyan = 'cyan';
  static const String gray = 'gray';

  static Color fromKey(AppThemeColors colors, String key) {
    return switch (key) {
      green => colors.chartGreen,
      red => colors.chartRed,
      blue => colors.chartBlue,
      purple => colors.chartPurple,
      orange => colors.primary,
      cyan => colors.chartBlue,
      gray => colors.textSecondary,
      _ => colors.primary,
    };
  }

  static Color backgroundFromKey(AppThemeColors colors, String key) {
    return switch (key) {
      green => colors.surfaceGreen,
      red => colors.surfaceRed,
      blue => colors.surfaceBlue,
      purple => colors.surfacePurple,
      orange => colors.primaryLight,
      cyan => colors.surfaceBlue,
      gray => colors.background,
      _ => colors.primaryLight,
    };
  }
}

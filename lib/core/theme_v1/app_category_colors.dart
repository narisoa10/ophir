import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppCategoryColors {
  AppCategoryColors._();

  static const String green = 'green';
  static const String red = 'red';
  static const String blue = 'blue';

  static Color fromKey(String key) {
    return switch (key) {
      green => AppColors.chartGreen,
      red => AppColors.chartRed,
      blue => AppColors.chartBlue,
      _ => AppColors.primary,
    };
  }

  static Color backgroundFromKey(String key) {
    return switch (key) {
      green => AppColors.surfaceGreen,
      red => AppColors.surfaceRed,
      blue => AppColors.surfaceBlue,
      _ => AppColors.primaryLight,
    };
  }
}

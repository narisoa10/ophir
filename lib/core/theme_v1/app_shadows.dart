import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'app_theme_colors.dart';

abstract final class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(BuildContext context) => [
    BoxShadow(
      color: context.appThemeColors.shadow,
      blurRadius: AppSpacing.lg,
      offset: Offset(AppSpacing.none, AppSpacing.xs),
    ),
  ];
}

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: AppSpacing.lg,
      offset: Offset(AppSpacing.none, AppSpacing.xs),
    ),
  ];
}

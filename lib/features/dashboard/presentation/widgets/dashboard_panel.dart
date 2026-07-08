import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_shadows.dart';
import '../../../../core/theme_v1/app_spacing.dart';

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    required this.child,
    this.padding = AppSpacing.cardInsets,
    this.borderRadius = AppRadius.smRadius,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: borderRadius,
        boxShadow: AppShadows.card,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

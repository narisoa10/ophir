import 'package:flutter/material.dart';

import '../theme_v1/app_radius.dart';
import '../theme_v1/app_spacing.dart';
import '../theme_v1/app_theme_colors.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = AppSpacing.cardInsets,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: AppRadius.cardRadius,
      ),
      // Ink from descendants (InkWell, IconButton) paints on this Material
      // above the card surface instead of on an ancestor below it.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

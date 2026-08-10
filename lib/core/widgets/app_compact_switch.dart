import 'package:flutter/material.dart';

import '../theme_v1/app_dimensions.dart';
import '../theme_v1/app_theme_colors.dart';

class AppCompactSwitch extends StatelessWidget {
  const AppCompactSwitch({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: onChanged != null,
      child: SizedBox(
        width: AppDimensions.buttonSmHeight,
        height: AppDimensions.avatarSm,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.textInverse,
            activeTrackColor: colors.primary,
            inactiveThumbColor: colors.surface,
            inactiveTrackColor: colors.border,
          ),
        ),
      ),
    );
  }
}

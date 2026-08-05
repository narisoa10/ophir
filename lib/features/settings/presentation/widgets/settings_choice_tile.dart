import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';

class SettingsChoiceTile<T> extends StatelessWidget {
  const SettingsChoiceTile({
    required this.title,
    required this.value,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final T value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return RadioListTile<T>(
      value: value,
      activeColor: colors.primary,
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.primary;
        }

        return colors.iconTertiary;
      }),
      contentPadding: AppSpacing.settingsTileInsets,
      title: Text(
        title,
        style: AppTypography.bodyStrong.copyWith(color: colors.textPrimary),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
    );
  }
}

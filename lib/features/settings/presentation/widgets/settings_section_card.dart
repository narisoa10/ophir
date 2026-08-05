import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.settingsSectionHeaderInsets,
          child: Text(
            title,
            style: AppTypography.captionStrong.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        Material(
          color: colors.surface,
          borderRadius: AppRadius.cardRadius,
          child: ClipRRect(
            borderRadius: AppRadius.cardRadius,
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index < children.length - 1)
                    Divider(
                      height: AppSpacing.hairline,
                      thickness: AppSpacing.hairline,
                      color: colors.divider,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

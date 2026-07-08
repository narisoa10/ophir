import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/settings_section.dart';
import 'settings_menu_tile.dart';

class SettingsSectionView extends StatelessWidget {
  const SettingsSectionView({required this.section, super.key});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.settingsSectionHeaderInsets,
          child: Text(
            section.title,
            style: AppTypography.captionStrong.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Column(
            children: [
              for (var index = 0; index < section.items.length; index++) ...[
                SettingsMenuTile(item: section.items[index]),
                if (index < section.items.length - 1)
                  const Divider(
                    height: AppSpacing.hairline,
                    thickness: AppSpacing.hairline,
                    color: AppColors.dividerColor,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

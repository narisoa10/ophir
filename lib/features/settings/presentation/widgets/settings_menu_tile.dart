import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/settings_item.dart';

class SettingsMenuTile extends StatelessWidget {
  const SettingsMenuTile({required this.item, super.key});

  final SettingsItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final contentColor = item.enabled
        ? colors.textPrimary
        : colors.textDisabled;
    final secondaryColor = item.enabled
        ? colors.textSecondary
        : colors.textDisabled;

    return InkWell(
      onTap: item.enabled ? item.onTap : null,
      child: Padding(
        padding: AppSpacing.settingsTileInsets,
        child: Row(
          children: [
            Icon(
              item.icon,
              color: item.enabled ? colors.iconSecondary : colors.textDisabled,
              size: AppDimensions.iconLg,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(
                      color: contentColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.hairline),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (item.enabled) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                AppIcons.actionChevronRight,
                color: colors.iconTertiary,
                size: AppDimensions.iconLg,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

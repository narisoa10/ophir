import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/settings_item.dart';

class SettingsMenuTile extends StatelessWidget {
  const SettingsMenuTile({required this.item, super.key});

  final SettingsItem item;

  @override
  Widget build(BuildContext context) {
    final contentColor = item.enabled
        ? AppColors.textPrimary
        : AppColors.textDisabled;
    final secondaryColor = item.enabled
        ? AppColors.textSecondary
        : AppColors.textDisabled;

    return InkWell(
      onTap: item.enabled ? item.onTap : null,
      child: Padding(
        padding: AppSpacing.settingsTileInsets,
        child: Row(
          children: [
            Icon(
              item.icon,
              color: item.enabled
                  ? AppColors.iconSecondary
                  : AppColors.textDisabled,
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
              const Icon(Icons.chevron_right, color: AppColors.iconTertiary),
            ],
          ],
        ),
      ),
    );
  }
}

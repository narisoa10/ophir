import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_shadows.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class DashboardOverviewCard extends StatelessWidget {
  const DashboardOverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smRadius,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: AppRadius.smRadius,
        child: InkWell(
          borderRadius: AppRadius.smRadius,
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.captionStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        value,
                        style: AppTypography.sectionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.iconSecondary,
                  size: AppDimensions.iconLg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

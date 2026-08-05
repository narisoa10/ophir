import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

/// Stage 1 — banner showing uncategorized count with filter toggle.
class OperationReviewBanner extends StatelessWidget {
  const OperationReviewBanner({
    required this.count,
    required this.label,
    required this.filterActive,
    required this.onToggleFilter,
    super.key,
  });

  final int count;
  final String label;
  final bool filterActive;
  final VoidCallback onToggleFilter;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: filterActive
            ? context.appThemeColors.primary.withValues(alpha: 0.12)
            : context.appThemeColors.surface,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onToggleFilter,
          child: Padding(
            padding: AppSpacing.compactListTileInsets,
            child: Row(
              children: [
                Icon(
                  Icons.label_outline,
                  size: 18,
                  color: filterActive
                      ? context.appThemeColors.primary
                      : context.appThemeColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.inlineGap),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyStrong.copyWith(
                      color: filterActive
                          ? context.appThemeColors.primary
                          : context.appThemeColors.textPrimary,
                    ),
                  ),
                ),
                if (filterActive)
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: context.appThemeColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

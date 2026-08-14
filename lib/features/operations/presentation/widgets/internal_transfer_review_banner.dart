import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';

/// Informational banner for candidate internal-transfer review (H2).
/// Distinct from [OperationReviewBanner] (category filter toggle).
class InternalTransferReviewBanner extends StatelessWidget {
  const InternalTransferReviewBanner({
    required this.count,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    super.key,
  });

  final int count;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: Material(
          color: context.appThemeColors.surface,
          borderRadius: AppRadius.cardRadius,
          child: InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: onTap,
            child: Padding(
              padding: AppSpacing.compactListTileInsets,
              child: Row(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 18,
                    color: context.appThemeColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.inlineGap),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.bodyStrong.copyWith(
                        color: context.appThemeColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.appThemeColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../categories/presentation/models/category_presentation.dart';
import 'operation_icon_badge.dart';

class OperationCategoryCompactTile extends StatelessWidget {
  const OperationCategoryCompactTile({
    required this.category,
    required this.onTap,
    super.key,
  });

  final CategoryPresentation category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.categoryPickerChipMinHeight,
        maxWidth: AppDimensions.categoryPickerChipMaxWidth,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.cardRadius,
        ),
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.categoryPickerChipInsets,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OperationIconBadge(
                  size: AppDimensions.categoryPickerIcon,
                  icon: category.icon,
                  iconSize: AppDimensions.categoryPickerIconGlyph,
                  iconColor: category.color,
                  backgroundColor: category.backgroundColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

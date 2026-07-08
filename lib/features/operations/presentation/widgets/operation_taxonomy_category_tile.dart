import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../categories/presentation/models/category_picker_taxonomy_item.dart';
import 'operation_icon_badge.dart';

class OperationTaxonomyCategoryTile extends StatelessWidget {
  const OperationTaxonomyCategoryTile({
    required this.item,
    required this.onTap,
    super.key,
  });

  final CategoryPickerTaxonomyItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final presentation = item.presentation;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.smRadius,
      ),
      child: InkWell(
        borderRadius: AppRadius.smRadius,
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.listTileInsets,
          child: Row(
            children: [
              OperationIconBadge(
                size: AppDimensions.avatarMd,
                icon: presentation.icon,
                iconSize: AppDimensions.iconMd,
                iconColor: presentation.color,
                backgroundColor: presentation.backgroundColor,
              ),
              const SizedBox(width: AppSpacing.inlineGap),
              Expanded(
                child: Text(
                  presentation.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body,
                ),
              ),
              const Icon(
                AppIcons.actionChevronRight,
                color: AppColors.iconTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../categories/presentation/models/category_presentation.dart';
import 'operation_icon_badge.dart';

class OperationCategoryTile extends StatelessWidget {
  const OperationCategoryTile({
    required this.category,
    required this.onTap,
    super.key,
  });

  final CategoryPresentation category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppSpacing.cardInsets,
      tileColor: AppColors.surface,
      leading: OperationIconBadge(
        size: AppDimensions.avatarMd,
        icon: category.icon,
        iconSize: AppDimensions.iconMd,
        iconColor: category.color,
        backgroundColor: category.backgroundColor,
      ),
      title: Text(category.name, style: AppTypography.body),
      trailing: const Icon(
        AppIcons.actionChevronRight,
        color: AppColors.iconTertiary,
      ),
      onTap: onTap,
    );
  }
}

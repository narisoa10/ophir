import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class OperationActionTile extends StatelessWidget {
  const OperationActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: AppColors.surface,
      contentPadding: AppSpacing.listTileInsets,
      shape: AppRadius.cardShape,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTypography.body),
      trailing: const Icon(
        AppIcons.actionChevronRight,
        color: AppColors.iconTertiary,
      ),
      onTap: onTap,
    );
  }
}

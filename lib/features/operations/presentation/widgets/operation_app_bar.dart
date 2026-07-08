import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class OperationAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OperationAppBar({required this.title, this.elevation, super.key});

  final String title;
  final double? elevation;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimensions.appBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: elevation ?? AppSpacing.none,
      title: Text(
        title,
        style: AppTypography.screenTitle.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

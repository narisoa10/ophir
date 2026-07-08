import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class ProfileTile extends StatelessWidget {
  const ProfileTile({
    required this.title,
    required this.value,
    super.key,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppSpacing.zero,
      title: Text(
        title,
        style: AppTypography.bodyMd.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        value,
        style: AppTypography.bodySm.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
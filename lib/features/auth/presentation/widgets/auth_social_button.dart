import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconSize = AppDimensions.iconMd,
    super.key,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.inputMdHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: AppBorders.defaultSide,
          shape: AppRadius.inputShape,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              icon,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: AppTypography.buttonMd.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
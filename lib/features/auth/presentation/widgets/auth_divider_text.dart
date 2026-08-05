import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class AuthDividerText extends StatelessWidget {
  const AuthDividerText({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            text,
            style: AppTypography.captionLg.copyWith(
              color: context.appThemeColors.textTertiary,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';

class AuthSignUpText extends StatelessWidget {
  const AuthSignUpText({
    required this.prefix,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String prefix;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: <Widget>[
        Text(
          '$prefix ',
          style: AppTypography.bodySm.copyWith(
            color: context.appThemeColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: AppTypography.bodySm.copyWith(
              color: context.appThemeColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

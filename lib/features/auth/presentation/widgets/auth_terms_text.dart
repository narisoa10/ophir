import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class AuthTermsText extends StatelessWidget {
  const AuthTermsText({
    required this.prefix,
    required this.terms,
    required this.andText,
    required this.privacy,
    required this.onTermsTap,
    required this.onPrivacyTap,
    super.key,
  });

  final String prefix;
  final String terms;
  final String andText;
  final String privacy;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: <Widget>[
        Text(
          '$prefix ',
          textAlign: TextAlign.center,
          style: AppTypography.captionLg.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: onTermsTap,
          child: Text(
            terms,
            style: AppTypography.captionLg.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          ' $andText ',
          style: AppTypography.captionLg.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: onPrivacyTap,
          child: Text(
            privacy,
            style: AppTypography.captionLg.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
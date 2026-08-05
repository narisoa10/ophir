import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class AuthSignUpSuggestion extends StatelessWidget {
  const AuthSignUpSuggestion({
    required this.l10n,
    required this.isLoading,
    required this.onSignUpPressed,
    super.key,
  });

  final AppLocalizations l10n;
  final bool isLoading;
  final VoidCallback onSignUpPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.authUserNotFound,
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            color: context.appThemeColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: isLoading ? null : onSignUpPressed,
          child: Text(l10n.authSignUp),
        ),
      ],
    );
  }
}

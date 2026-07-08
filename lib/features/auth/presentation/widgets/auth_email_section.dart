import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/validation/email/email_validation_mapper.dart';
import '../../controller/auth_state.dart';
import 'auth_text_field.dart';

class AuthEmailSection extends StatelessWidget {
  const AuthEmailSection({
    required this.controller,
    required this.authState,
    required this.l10n,
    required this.isLoading,
    required this.onChanged,
    required this.onSuggestionSelected,
    super.key,
  });

  final TextEditingController controller;
  final AuthState authState;
  final AppLocalizations l10n;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    final emailError = authState.emailError?.localized(l10n);

    return Column(
      children: [
        AuthTextField(
          controller: controller,
          hintText: l10n.authEmailHint,
          keyboardType: TextInputType.emailAddress,
          onChanged: onChanged,
        ),
        if (emailError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            emailError,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
        if (authState.hasEmailSuggestion) ...[
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: isLoading
                ? null
                : () => onSuggestionSelected(authState.emailSuggestion!),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Text.rich(
                TextSpan(
                  text: '${l10n.authEmailSuggestion}\n',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: authState.emailSuggestion!,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
        if (authState.emailSuggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Column(
            children: authState.emailSuggestions
                .where((suggestion) => suggestion != authState.emailSuggestion)
                .take(3)
                .map(
                  (suggestion) => InkWell(
                onTap: isLoading
                    ? null
                    : () => onSuggestionSelected(suggestion),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    suggestion,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ],
      ],
    );
  }
}
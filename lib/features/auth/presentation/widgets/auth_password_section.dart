import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../../core/validation/password/password_requirement.dart';
import '../../../../core/validation/password/password_validation_result.dart';
import '../../controller/auth_state.dart';
import 'auth_text_field.dart';

class AuthPasswordSection extends StatelessWidget {
  const AuthPasswordSection({
    required this.controller,
    required this.authState,
    required this.l10n,
    required this.obscurePassword,
    required this.onToggleVisibility,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final AuthState authState;
  final AppLocalizations l10n;
  final bool obscurePassword;
  final VoidCallback onToggleVisibility;
  final ValueChanged<String> onChanged;

  bool get _hasPasswordInput => controller.text.isNotEmpty;

  bool get _hasFailedRequirements =>
      authState.passwordFailedRequirements.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        AuthTextField(
          controller: controller,
          hintText: l10n.authPasswordHint,
          obscureText: obscurePassword,
          suffixIcon: obscurePassword ? AppIcons.eye : AppIcons.eyeOff,
          onSuffixTap: onToggleVisibility,
          onChanged: onChanged,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: !_hasPasswordInput
              ? const SizedBox.shrink()
              : _hasFailedRequirements
              ? _PasswordRequirementsList(
                  key: const ValueKey('password_requirements'),
                  authState: authState,
                  l10n: l10n,
                )
              : _PasswordStrengthIndicator(
                  key: const ValueKey('password_strength'),
                  strength: authState.passwordStrength,
                  l10n: l10n,
                ),
        ),
      ],
    );
  }
}

class _PasswordRequirementsList extends StatelessWidget {
  const _PasswordRequirementsList({
    required this.authState,
    required this.l10n,
    super.key,
  });

  final AuthState authState;
  final AppLocalizations l10n;

  static const List<PasswordRequirement> _requirements = [
    PasswordRequirement.minLength,
    PasswordRequirement.noSpaces,
    PasswordRequirement.lowercaseLetter,
    PasswordRequirement.uppercaseLetter,
    PasswordRequirement.number,
    PasswordRequirement.specialCharacter,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _requirements.map((requirement) {
          final isPassed = authState.passwordPassedRequirements.contains(
            requirement,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  isPassed ? AppIcons.actionSuccess : AppIcons.actionError,
                  size: 14,
                  color: isPassed ? colors.success : colors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _requirementText(requirement, l10n),
                    style: AppTypography.bodySm.copyWith(
                      color: isPassed ? colors.textSecondary : colors.error,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _requirementText(
    PasswordRequirement requirement,
    AppLocalizations l10n,
  ) {
    switch (requirement) {
      case PasswordRequirement.minLength:
        return l10n.passwordRequirementMinLength;
      case PasswordRequirement.maxLength:
        return l10n.passwordRequirementMaxLength;
      case PasswordRequirement.noSpaces:
        return l10n.passwordRequirementNoSpaces;
      case PasswordRequirement.lowercaseLetter:
        return l10n.passwordRequirementLowercase;
      case PasswordRequirement.uppercaseLetter:
        return l10n.passwordRequirementUppercase;
      case PasswordRequirement.number:
        return l10n.passwordRequirementNumber;
      case PasswordRequirement.specialCharacter:
        return l10n.passwordRequirementSpecial;
    }
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({
    required this.strength,
    required this.l10n,
    super.key,
  });

  final PasswordStrength strength;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final color = _strengthColor(colors, strength);
    final value = _strengthValue(strength);
    final label = _strengthLabel(strength, l10n);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: value,
              backgroundColor: colors.textSecondary.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.right,
            style: AppTypography.bodySm.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _strengthColor(AppThemeColors colors, PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return colors.textSecondary;
      case PasswordStrength.weak:
        return colors.error;
      case PasswordStrength.medium:
        return colors.warning;
      case PasswordStrength.strong:
        return colors.success;
    }
  }

  double _strengthValue(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return 0;
      case PasswordStrength.weak:
        return 0.35;
      case PasswordStrength.medium:
        return 0.68;
      case PasswordStrength.strong:
        return 1;
    }
  }

  String _strengthLabel(PasswordStrength strength, AppLocalizations l10n) {
    switch (strength) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return l10n.passwordStrengthWeak;
      case PasswordStrength.medium:
        return l10n.passwordStrengthMedium;
      case PasswordStrength.strong:
        return l10n.passwordStrengthStrong;
    }
  }
}

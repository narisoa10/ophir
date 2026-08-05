import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class OperationMonthNavigator extends StatelessWidget {
  const OperationMonthNavigator({
    required this.monthLabel,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onMonthTap,
    super.key,
  });

  final String monthLabel;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onMonthTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.operationsMonthNavigatorLabel(monthLabel),
      child: Row(
        children: [
          _NavigationButton(
            icon: Icons.chevron_left_rounded,
            enabled: canGoBack,
            tooltip: l10n.operationsPreviousMonth,
            onPressed: onPreviousMonth,
          ),
          Expanded(
            child: InkWell(
              onTap: onMonthTap,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  monthLabel,
                  style: AppTypography.bodyStrong,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          _NavigationButton(
            icon: AppIcons.actionChevronRight,
            enabled: canGoForward,
            tooltip: l10n.operationsNextMonth,
            onPressed: onNextMonth,
          ),
        ],
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      icon: Icon(
        icon,
        color: enabled
            ? context.appThemeColors.iconPrimary
            : context.appThemeColors.textDisabled,
      ),
    );
  }
}

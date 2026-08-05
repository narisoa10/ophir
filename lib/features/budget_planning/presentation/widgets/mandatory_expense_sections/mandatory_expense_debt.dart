import 'package:flutter/material.dart';

import '../../../../../core/categories/app_categories.dart';
import '../../../../../core/formatters/app_money_formatter.dart';
import '../../../../../core/icons/app_category_icons.dart';
import '../../../../../core/icons/app_icons.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import '../../../../../core/theme_v1/app_category_colors.dart';
import '../../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../../core/theme_v1/app_dimensions.dart';
import '../../../../../core/theme_v1/app_radius.dart';
import '../../../../../core/theme_v1/app_spacing.dart';
import '../../../../../core/theme_v1/app_typography.dart';
import '../../../../../core/widgets/app_category_group_section.dart';
import '../../../../../core/widgets/app_financial_list_tile.dart';
import '../../../domain/entities/budget_obligation.dart';
import '../../../domain/enums/budget_frequency.dart';

class MandatoryExpenseDebt extends StatelessWidget {
  const MandatoryExpenseDebt({
    required this.obligations,
    this.formattedAmount = '0.00 CAD',
    required this.isExpanded,
    required this.onToggle,
    required this.currencyCode,
    required this.onAddDebt,
    required this.onDebtTap,
    super.key,
  });

  final List<BudgetObligation> obligations;
  final String formattedAmount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String currencyCode;
  final VoidCallback onAddDebt;
  final ValueChanged<BudgetObligation> onDebtTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    return AppCategoryGroupSection(
      isExpanded: isExpanded,
      showChildConnector: true,
      header: AppFinancialListTile(
        icon: AppIcons.operationCategory,
        iconColor: AppCategoryColors.fromKey(colors, AppCategoryColors.orange),
        iconBackgroundColor: AppCategoryColors.backgroundFromKey(
          colors,
          AppCategoryColors.orange,
        ),
        title: l10n.budgetDebtTitle,
        subtitle: formattedAmount,
        semanticsLabel: '${l10n.budgetDebtTitle}, $formattedAmount',
        onTap: onToggle,
        isExpanded: isExpanded,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.hairline,
        ),
      ),
      children: [
        for (final obligation in obligations)
          _DebtTile(
            obligation: obligation,
            currencyCode: currencyCode,
            onTap: () => onDebtTap(obligation),
          ),
        _AddDebtTile(onTap: onAddDebt),
      ],
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.obligation,
    required this.currencyCode,
    required this.onTap,
  });

  final BudgetObligation obligation;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;
    final category = AppCategories.byIdName(obligation.categoryId);
    final colorKey = category?.colorKey ?? AppCategoryColors.green;
    final title = obligation.name?.trim().isNotEmpty == true
        ? obligation.name!.trim()
        : category?.name(l10n) ?? l10n.budgetDebtTitle;
    final subtitle = _summary(l10n);

    return AppFinancialListTile(
      icon: AppCategoryIcons.fromKey(
        category?.iconKey ?? AppCategoryIcons.debtRepayment,
      ),
      iconColor: AppCategoryColors.fromKey(colors, colorKey),
      iconBackgroundColor: AppCategoryColors.backgroundFromKey(
        colors,
        colorKey,
      ),
      title: title,
      subtitle: subtitle,
      semanticsLabel: '$title, $subtitle',
      onTap: onTap,
      level: AppFinancialListTileLevel.child,
    );
  }

  String _summary(AppLocalizations l10n) {
    final amount = formatMoney(
      obligation.amount,
      currencyCode,
      showPositiveSign: false,
    );

    return '$amount \u2022 ${_frequencyLabel(obligation.frequency, l10n)}';
  }

  String _frequencyLabel(BudgetFrequency frequency, AppLocalizations l10n) {
    return switch (frequency) {
      BudgetFrequency.daily => l10n.budgetFrequencyDaily,
      BudgetFrequency.weekly => l10n.budgetFrequencyWeekly,
      BudgetFrequency.biweekly => l10n.budgetFrequencyBiweekly,
      BudgetFrequency.semiMonthly => l10n.budgetFrequencySemiMonthly,
      BudgetFrequency.monthly => l10n.budgetFrequencyMonthly,
      BudgetFrequency.everyNMonths => l10n.budgetFrequencyEveryNMonths,
      BudgetFrequency.timesPerYear => l10n.budgetFrequencyTimesPerYear,
      BudgetFrequency.yearly => l10n.budgetFrequencyYearly,
      BudgetFrequency.irregular => l10n.budgetFrequencyIrregular,
    };
  }
}

class _AddDebtTile extends StatelessWidget {
  const _AddDebtTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Material(
        color: colors.background,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.listTileInsets,
            child: Row(
              children: [
                Icon(
                  AppIcons.actionAdd,
                  color: colors.primary,
                  size: AppDimensions.iconMd,
                ),
                const SizedBox(width: AppSpacing.inlineGap),
                Expanded(
                  child: Text(
                    l10n.budgetDebtAdd,
                    style: AppTypography.bodyStrong.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

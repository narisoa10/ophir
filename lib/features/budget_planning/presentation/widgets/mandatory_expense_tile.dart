import 'package:flutter/material.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/formatters/app_money_formatter.dart';
import '../../../../core/icons/app_category_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/widgets/app_financial_list_tile.dart';
import '../../domain/entities/budget_obligation.dart';
import '../../domain/enums/budget_frequency.dart';

class MandatoryExpenseTile extends StatelessWidget {
  const MandatoryExpenseTile({
    required this.category,
    required this.obligation,
    required this.currencyCode,
    required this.onTap,
    super.key,
  });

  final AppCategory category;
  final BudgetObligation? obligation;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;
    final color = AppCategoryColors.fromKey(colors, category.colorKey);
    final title = category.name(l10n);
    final subtitle = category.group == AppCategoryGroup.housing
        ? _housingSummary(l10n)
        : _summary(context, l10n);

    return AppFinancialListTile(
      icon: AppCategoryIcons.fromKey(category.iconKey),
      iconColor: color,
      iconBackgroundColor: AppCategoryColors.backgroundFromKey(
        colors,
        category.colorKey,
      ),
      title: title,
      subtitle: subtitle,
      semanticsLabel: '$title, $subtitle',
      onTap: onTap,
      level: AppFinancialListTileLevel.child,
    );
  }

  String _summary(BuildContext context, AppLocalizations l10n) {
    final value = obligation;

    if (value == null) {
      return AppLocalizations.of(context).budgetExpenseNotFilled;
    }

    final amount = formatMoney(
      value.amount,
      currencyCode,
      showPositiveSign: false,
    );
    final frequency = _frequencyLabel(value.frequency, l10n);
    final date = value.nextDueDate == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(value.nextDueDate!);

    return [
      amount,
      frequency,
      ...[date],
    ].join(' \u2022 ');
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

  String _housingSummary(AppLocalizations l10n) {
    final value = obligation;

    if (value == null) {
      return l10n.budgetExpenseNotFilled;
    }

    final amount = formatMoney(
      value.amount,
      currencyCode,
      showPositiveSign: false,
    );
    final frequency = _frequencyLabel(value.frequency, l10n);

    return '$amount \u2022 $frequency';
  }
}

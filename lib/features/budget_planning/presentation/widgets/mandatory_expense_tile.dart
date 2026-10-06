import 'package:flutter/material.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/formatters/app_money_formatter.dart';
import '../../../../core/icons/app_category_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/widgets/app_financial_list_tile.dart';
import '../../domain/entities/budget_obligation.dart';
import '../mappers/budget_frequency_localization.dart';

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
      locale: l10n.localeName,
    );
    final frequency = value.frequency.localized(l10n);
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

  String _housingSummary(AppLocalizations l10n) {
    final value = obligation;

    if (value == null) {
      return l10n.budgetExpenseNotFilled;
    }

    final amount = formatMoney(
      value.amount,
      currencyCode,
      locale: l10n.localeName,
    );
    final frequency = value.frequency.localized(l10n);

    return '$amount \u2022 $frequency';
  }
}

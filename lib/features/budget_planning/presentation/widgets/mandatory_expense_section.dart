import 'package:flutter/material.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/formatters/app_money_formatter.dart';
import '../../../../core/icons/app_category_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/widgets/app_category_group_section.dart';
import '../../../../core/widgets/app_financial_list_tile.dart';
import '../../domain/entities/budget_obligation.dart';
import 'mandatory_expense_tile.dart';

class MandatoryExpenseSection extends StatelessWidget {
  const MandatoryExpenseSection({
    required this.title,
    required this.iconKey,
    required this.categories,
    required this.selectedCount,
    this.formattedAmount = '0.00 CAD',
    required this.isExpanded,
    required this.onToggle,
    required this.currencyCode,
    required this.obligationFor,
    required this.onCategoryTap,
    super.key,
  });

  final String title;
  final String iconKey;
  final List<AppCategory> categories;
  final int selectedCount;
  final String formattedAmount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String currencyCode;
  final BudgetObligation? Function(AppCategory category) obligationFor;
  final ValueChanged<AppCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final colorKey = categories.isEmpty
        ? AppCategoryColors.orange
        : categories.first.colorKey;

    return AppCategoryGroupSection(
      isExpanded: isExpanded,
      showChildConnector: true,
      header: AppFinancialListTile(
        icon: AppCategoryIcons.fromKey(iconKey),
        iconColor: AppCategoryColors.fromKey(colors, colorKey),
        iconBackgroundColor: AppCategoryColors.backgroundFromKey(
          colors,
          colorKey,
        ),
        title: title,
        subtitle: formattedAmount,
        semanticsLabel: '$title, $formattedAmount',
        onTap: onToggle,
        isExpanded: isExpanded,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.hairline,
        ),
      ),
      children: [
        for (final category in categories)
          category.id == AppCategoryId.expenseGivingTithe
              ? _TitheExpenseTile(
                  category: category,
                  obligation: obligationFor(category),
                  currencyCode: currencyCode,
                  onChanged: () => onCategoryTap(category),
                )
              : MandatoryExpenseTile(
                  category: category,
                  obligation: obligationFor(category),
                  currencyCode: currencyCode,
                  onTap: () => onCategoryTap(category),
                ),
      ],
    );
  }
}

class _TitheExpenseTile extends StatelessWidget {
  const _TitheExpenseTile({
    required this.category,
    required this.obligation,
    required this.currencyCode,
    required this.onChanged,
  });

  final AppCategory category;
  final BudgetObligation? obligation;
  final String currencyCode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;
    final color = AppCategoryColors.fromKey(colors, category.colorKey);
    final isEnabled = obligation != null;
    final title = category.name(l10n);
    final subtitle = _summary(context, l10n);

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
      onTap: null,
      level: AppFinancialListTileLevel.child,
      trailing: Semantics(
        container: true,
        label: l10n.budgetTitheSwitchLabel,
        value: isEnabled
            ? l10n.budgetTitheSwitchValueEnabled
            : l10n.budgetTitheSwitchValueDisabled,
        toggled: isEnabled,
        child: Switch(value: isEnabled, onChanged: (_) => onChanged()),
      ),
    );
  }

  String _summary(BuildContext context, AppLocalizations l10n) {
    final value = obligation;

    if (value == null) {
      return l10n.budgetTitheDisabled;
    }

    final amount = formatMoney(
      value.amount,
      currencyCode,
      showPositiveSign: false,
    );

    return '$amount \u2022 ${l10n.budgetFrequencyMonthly}';
  }
}

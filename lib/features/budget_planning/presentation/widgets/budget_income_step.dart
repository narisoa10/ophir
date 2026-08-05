import 'package:flutter/material.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/formatters/app_money_formatter.dart';
import '../../../../core/icons/app_category_icons.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../../core/widgets/app_financial_list_tile.dart';
import '../../domain/entities/budget_income_source.dart';
import '../../domain/entities/budget_setup.dart';
import '../../domain/enums/budget_frequency.dart';
import 'budget_income_editor_sheet.dart';

class BudgetIncomeStep extends StatefulWidget {
  const BudgetIncomeStep({
    required this.setup,
    required this.currencyCode,
    super.key,
  });

  final BudgetSetup setup;
  final String currencyCode;

  @override
  BudgetIncomeStepState createState() => BudgetIncomeStepState();
}

class BudgetIncomeStepState extends State<BudgetIncomeStep> {
  late List<BudgetIncomeSource> _items;
  bool _showEmptyError = false;

  @override
  void initState() {
    super.initState();
    _items = _incomeSourcesFor(widget.setup);
  }

  @override
  void didUpdateWidget(BudgetIncomeStep oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.setup.id != widget.setup.id ||
        oldWidget.setup.incomeSources != widget.setup.incomeSources) {
      _items = _incomeSourcesFor(widget.setup);
      _showEmptyError = false;
    }
  }

  List<BudgetIncomeSource> _incomeSourcesFor(BudgetSetup setup) {
    return setup.incomeSources.toList(growable: true);
  }

  List<BudgetIncomeSource>? validateAndCreateIncomeSources() {
    if (_items.isEmpty) {
      setState(() {
        _showEmptyError = true;
      });
      return null;
    }

    return _items.toList(growable: false);
  }

  Future<void> _openEditor([BudgetIncomeSource? income]) async {
    final result = await showModalBottomSheet<BudgetIncomeEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return BudgetIncomeEditorSheet(
          existingIncome: income,
          currencyCode: widget.currencyCode,
          setupId: widget.setup.id,
          userId: widget.setup.userId,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _showEmptyError = false;

      if (result.isDeleted) {
        if (income != null) {
          _items.removeWhere((item) => item.id == income.id);
        }
        return;
      }

      final savedIncome = result.income;
      if (savedIncome == null) {
        return;
      }

      final index = _items.indexWhere((item) => item.id == savedIncome.id);
      if (index == -1) {
        _items.add(savedIncome);
        return;
      }

      _items[index] = savedIncome;
    });
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.budgetIncomeTitle, style: AppTypography.headingMd),
        const SizedBox(height: AppSpacing.screenGap),
        for (final income in _items) ...[
          _incomeSourceTile(income, l10n),
          const SizedBox(height: AppSpacing.sm),
        ],
        _AddIncomeSourceTile(onTap: () => _openEditor()),
        if (_showEmptyError) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l10n.budgetRequiredField,
              style: AppTypography.caption.copyWith(
                color: context.appThemeColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _incomeSourceTile(BudgetIncomeSource income, AppLocalizations l10n) {
    final colors = context.appThemeColors;
    final category = AppCategories.byIdName(income.categoryId);
    final colorKey = category?.colorKey ?? AppCategoryColors.green;
    final color = AppCategoryColors.fromKey(colors, colorKey);
    final title = income.name.trim().isEmpty
        ? category?.name(l10n) ?? l10n.budgetIncomeSelectCategory
        : income.name.trim();
    final summary = _summary(income, l10n);

    return AppFinancialListTile(
      icon: category == null
          ? AppIcons.categoryIncome
          : AppCategoryIcons.fromKey(category.iconKey),
      iconColor: color,
      iconBackgroundColor: AppCategoryColors.backgroundFromKey(
        colors,
        colorKey,
      ),
      title: title,
      subtitle: summary,
      semanticsLabel: '$title, $summary',
      onTap: () => _openEditor(income),
    );
  }

  String _summary(BudgetIncomeSource income, AppLocalizations l10n) {
    final currencyCode = income.currencyCode.isEmpty
        ? widget.currencyCode
        : income.currencyCode;
    final amount = formatMoney(
      income.amount,
      currencyCode,
      showPositiveSign: false,
    );

    return '$amount / ${_frequencyLabel(income.frequency, l10n)}';
  }
}

class _AddIncomeSourceTile extends StatelessWidget {
  const _AddIncomeSourceTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    return Semantics(
      button: true,
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
                    l10n.budgetIncomeAddSource,
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

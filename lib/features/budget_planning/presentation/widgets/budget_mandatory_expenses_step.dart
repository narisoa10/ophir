import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/categories/aggregation/app_category_group_summary.dart';
import '../../../../core/categories/app_categories.dart';
import '../../../../core/formatters/app_money_formatter.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/budget_income_source.dart';
import '../../domain/entities/budget_obligation.dart';
import '../../domain/entities/budget_setup.dart';
import '../../domain/enums/budget_data_confidence.dart';
import '../../domain/enums/budget_data_source.dart';
import '../../domain/enums/budget_frequency.dart';
import 'budget_category_amount_entries.dart';
import 'mandatory_debt_editor_sheet.dart';
import 'mandatory_expense_editor_sheet.dart';
import 'mandatory_expense_sections/mandatory_expense_debt.dart';
import 'mandatory_expense_sections/mandatory_expense_education.dart';
import 'mandatory_expense_sections/mandatory_expense_family.dart';
import 'mandatory_expense_sections/mandatory_expense_finance.dart';
import 'mandatory_expense_sections/mandatory_expense_food.dart';
import 'mandatory_expense_sections/mandatory_expense_giving.dart';
import 'mandatory_expense_sections/mandatory_expense_government.dart';
import 'mandatory_expense_sections/mandatory_expense_health.dart';
import 'mandatory_expense_sections/mandatory_expense_housing.dart';
import 'mandatory_expense_sections/mandatory_expense_pets.dart';
import 'mandatory_expense_sections/mandatory_expense_personal_care.dart';
import 'mandatory_expense_sections/mandatory_expense_transportation.dart';

class BudgetMandatoryExpensesStep extends StatefulWidget {
  const BudgetMandatoryExpensesStep({
    required this.setup,
    required this.currencyCode,
    super.key,
  });

  final BudgetSetup setup;
  final String currencyCode;

  @override
  BudgetMandatoryExpensesStepState createState() =>
      BudgetMandatoryExpensesStepState();
}

class BudgetMandatoryExpensesStepState
    extends State<BudgetMandatoryExpensesStep> {
  late Map<String, BudgetObligation> _obligationsByCategoryId;
  late Map<String, BudgetObligation> _debtObligationsById;
  late bool _isTitheEnabled;

  final _deletedCategoryIds = <String>{};

  String? _generatedTitheObligationId;

  bool _isHousingExpanded = false;
  bool _isTransportExpanded = false;
  bool _isFoodExpanded = false;
  bool _isHealthExpanded = false;
  bool _isFamilyExpanded = false;
  bool _isPersonalCareExpanded = false;
  bool _isEducationExpanded = false;
  bool _isFinanceExpanded = false;
  bool _isGovernmentExpanded = false;
  bool _isPetsExpanded = false;
  bool _isGivingExpanded = false;
  bool _isDebtExpanded = false;

  static const _sectionGap = AppSpacing.sm;
  static const _titheRate = 0.10;
  static const _uuid = Uuid();

  static final _titheCategoryId = AppCategoryId.expenseGivingTithe.name;

  @override
  void initState() {
    super.initState();

    _obligationsByCategoryId = _obligationsByCategoryIdFor(
      widget.setup.obligations,
    );
    _debtObligationsById = _debtObligationsByIdFor(widget.setup.obligations);

    _isTitheEnabled = _hasPersistedTitheObligation(widget.setup.obligations);
  }

  @override
  void didUpdateWidget(BudgetMandatoryExpensesStep oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.setup.id != widget.setup.id ||
        oldWidget.setup.obligations != widget.setup.obligations) {
      _obligationsByCategoryId = _obligationsByCategoryIdFor(
        widget.setup.obligations,
      );

      _debtObligationsById = _debtObligationsByIdFor(widget.setup.obligations);

      _isTitheEnabled = _hasPersistedTitheObligation(widget.setup.obligations);

      _generatedTitheObligationId = null;
      _deletedCategoryIds.clear();
    }
  }

  List<BudgetObligation>? validateAndCreateObligations() {
    final titheObligation = _titheObligationForPersistence();

    final obligations = [
      for (final entry in _obligationsByCategoryId.entries)
        if (entry.key != _titheCategoryId &&
            !_deletedCategoryIds.contains(entry.key))
          entry.value,
      ?titheObligation,
      ..._debtObligationsById.values,
    ];

    return obligations;
  }

  bool _hasPersistedTitheObligation(List<BudgetObligation> obligations) {
    final hasTithe = obligations.any(
      (obligation) => obligation.categoryId == _titheCategoryId,
    );
    if (!hasTithe) {
      return true;
    }
    return obligations.any(
      (obligation) =>
          obligation.categoryId == _titheCategoryId && obligation.isActive,
    );
  }

  Map<String, BudgetObligation> _obligationsByCategoryIdFor(
    List<BudgetObligation> obligations,
  ) {
    return {
      for (final obligation in obligations)
        if (obligation.categoryId != null && !_isDebtObligation(obligation))
          obligation.categoryId!: obligation,
    };
  }

  Map<String, BudgetObligation> _debtObligationsByIdFor(
    List<BudgetObligation> obligations,
  ) {
    return {
      for (final obligation in obligations)
        if (_isDebtObligation(obligation)) obligation.id: obligation,
    };
  }

  bool _isDebtObligation(BudgetObligation obligation) {
    return AppCategories.byIdName(obligation.categoryId)?.role ==
        AppCategoryRole.debtPayment;
  }

  BudgetObligation? _obligationFor(AppCategory category) {
    if (_isTitheCategory(category)) {
      return _titheObligationForDisplay();
    }

    final categoryId = category.id.name;

    if (_deletedCategoryIds.contains(categoryId)) {
      return null;
    }

    return _obligationsByCategoryId[categoryId];
  }

  bool _hasSelectedObligation(AppCategory category) {
    if (_isTitheCategory(category)) {
      return _isTitheEnabled;
    }

    return _obligationFor(category) != null;
  }

  bool _isTitheCategory(AppCategory category) {
    return category.id == AppCategoryId.expenseGivingTithe;
  }

  BudgetObligation? _titheObligationForDisplay() {
    if (!_isTitheEnabled) {
      return null;
    }

    return _buildTitheObligation(_titheMonthlyAmount());
  }

  BudgetObligation? _titheObligationForPersistence() {
    if (!_isTitheEnabled) {
      return null;
    }

    final amount = _titheMonthlyAmount();

    if (amount <= 0) {
      return null;
    }

    return _buildTitheObligation(amount);
  }

  BudgetObligation _buildTitheObligation(double amount) {
    final existing = _obligationsByCategoryId[_titheCategoryId];

    return BudgetObligation(
      id: _titheObligationId(existing?.id),
      setupId: widget.setup.id,
      userId: widget.setup.userId,
      categoryId: _titheCategoryId,
      obligationType: existing?.obligationType ?? 'living_expense',
      amount: amount,
      currencyCode: existing?.currencyCode ?? widget.currencyCode,
      frequency: BudgetFrequency.monthly,
      frequencyInterval: 1,
      timesPerYear: 12,
      nextDueDate: existing?.nextDueDate,
      minimumDebtPayment: existing?.minimumDebtPayment,
      name: existing?.name,
      isOverdue: existing?.isOverdue ?? false,
      source: existing?.source ?? BudgetDataSource.systemCalculated,
      confidence: existing?.confidence ?? BudgetDataConfidence.estimated,
      isActive: true,
      note: existing?.note,
    );
  }

  String _titheObligationId(String? existingId) {
    if (existingId != null && _isUuid(existingId)) {
      return existingId;
    }

    return _generatedTitheObligationId ??= _uuid.v4();
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  double _titheMonthlyAmount() {
    return _totalMonthlyIncome() * _titheRate;
  }

  double _totalMonthlyIncome() {
    return widget.setup.incomeSources.fold<double>(
      0,
      (total, incomeSource) => total + _monthlyIncomeAmount(incomeSource),
    );
  }

  double _monthlyIncomeAmount(BudgetIncomeSource incomeSource) {
    final timesPerYear = _incomeTimesPerYear(incomeSource);

    if (timesPerYear <= 0) {
      return 0;
    }

    return incomeSource.amount * timesPerYear / 12;
  }

  double _incomeTimesPerYear(BudgetIncomeSource incomeSource) {
    final customTimesPerYear = incomeSource.timesPerYear;

    return switch (incomeSource.frequency) {
      BudgetFrequency.daily => customTimesPerYear?.toDouble() ?? 365,
      BudgetFrequency.weekly => customTimesPerYear?.toDouble() ?? 52,
      BudgetFrequency.biweekly => customTimesPerYear?.toDouble() ?? 26,
      BudgetFrequency.semiMonthly => customTimesPerYear?.toDouble() ?? 24,
      BudgetFrequency.monthly => 12,
      BudgetFrequency.everyNMonths => _timesPerYearForMonthInterval(
        incomeSource.frequencyInterval,
      ),
      BudgetFrequency.timesPerYear => customTimesPerYear?.toDouble() ?? 0,
      BudgetFrequency.yearly => customTimesPerYear?.toDouble() ?? 1,
      BudgetFrequency.irregular => customTimesPerYear?.toDouble() ?? 0,
    };
  }

  double _timesPerYearForMonthInterval(int? frequencyInterval) {
    if (frequencyInterval == null || frequencyInterval <= 0) {
      return 0;
    }

    return 12 / frequencyInterval;
  }

  List<AppCategory> _mandatoryCategories(AppCategoryGroup group) {
    return AppCategories.mandatoryExpenseCategories(group);
  }

  Map<AppCategoryGroup, AppCategoryGroupFinancialSummary>
  _mandatorySummariesByGroup(List<AppCategory> categories) {
    final plannedObligations = [
      for (final category in categories) ?_obligationFor(category),
    ];

    final summaries = AppCategoryGroupSummaryBuilder.build(
      categoryScope: categories,
      plannedEntries: budgetPlannedCategoryAmountEntries(plannedObligations),
      actualEntries: const <AppCategoryAmountEntry>[],
    );

    return {for (final summary in summaries) summary.group: summary};
  }

  String _formattedPlannedAmount(
    Map<AppCategoryGroup, AppCategoryGroupFinancialSummary> summaries,
    AppCategoryGroup group,
  ) {
    return formatMoney(
      summaries[group]?.plannedAmount ?? 0,
      widget.currencyCode,
      showPositiveSign: false,
    );
  }

  String _formattedDebtPlannedAmount(List<BudgetObligation> obligations) {
    final summaries = AppCategoryGroupSummaryBuilder.build(
      categoryScope: AppCategories.debtPaymentCategories,
      plannedEntries: budgetPlannedCategoryAmountEntries(obligations),
      actualEntries: const <AppCategoryAmountEntry>[],
    );

    final amount = summaries.fold<double>(
      0,
      (total, summary) => total + summary.plannedAmount,
    );

    return formatMoney(amount, widget.currencyCode, showPositiveSign: false);
  }

  Future<void> _openEditor(AppCategory category) async {
    final result = await showModalBottomSheet<MandatoryExpenseEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return MandatoryExpenseEditorSheet(
          category: category,
          existingObligation: _obligationFor(category),
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
      final categoryId = category.id.name;

      if (result.isDeleted) {
        _obligationsByCategoryId.remove(categoryId);
        _deletedCategoryIds.add(categoryId);
        return;
      }

      final obligation = result.obligation;
      if (obligation != null) {
        _obligationsByCategoryId[categoryId] = obligation;
        _deletedCategoryIds.remove(categoryId);
      }
    });
  }

  void _handleCategoryTap(AppCategory category) {
    if (_isTitheCategory(category)) {
      setState(() {
        _isTitheEnabled = !_isTitheEnabled;
      });
      return;
    }

    _openEditor(category);
  }

  Future<void> _openDebtEditor([BudgetObligation? obligation]) async {
    final result = await showModalBottomSheet<MandatoryDebtEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return MandatoryDebtEditorSheet(
          existingObligation: obligation,
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
      if (result.isDeleted) {
        if (obligation != null) {
          _debtObligationsById.remove(obligation.id);
        }
        return;
      }

      final savedObligation = result.obligation;

      if (savedObligation != null) {
        _debtObligationsById[savedObligation.id] = savedObligation;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final housingCategories = _mandatoryCategories(AppCategoryGroup.housing);

    final transportCategories = _mandatoryCategories(
      AppCategoryGroup.transportation,
    );

    final foodCategories = _mandatoryCategories(AppCategoryGroup.food);

    final healthCategories = _mandatoryCategories(AppCategoryGroup.health);

    final familyCategories = _mandatoryCategories(AppCategoryGroup.family);

    final personalCareCategories = _mandatoryCategories(
      AppCategoryGroup.personalCare,
    );

    final educationCategories = _mandatoryCategories(
      AppCategoryGroup.education,
    );

    final financeCategories = _mandatoryCategories(AppCategoryGroup.finance);

    final governmentCategories = _mandatoryCategories(
      AppCategoryGroup.governmentExpense,
    );

    final petsCategories = _mandatoryCategories(AppCategoryGroup.pets);

    final givingCategories = _mandatoryCategories(AppCategoryGroup.giving);

    final mandatoryCategories = [
      ...housingCategories,
      ...transportCategories,
      ...foodCategories,
      ...healthCategories,
      ...familyCategories,
      ...personalCareCategories,
      ...educationCategories,
      ...financeCategories,
      ...governmentCategories,
      ...petsCategories,
      ...givingCategories,
    ];

    final mandatorySummaries = _mandatorySummariesByGroup(mandatoryCategories);

    final housingSelectedCount = housingCategories
        .where(_hasSelectedObligation)
        .length;

    final transportSelectedCount = transportCategories
        .where(_hasSelectedObligation)
        .length;

    final foodSelectedCount = foodCategories
        .where(_hasSelectedObligation)
        .length;

    final healthSelectedCount = healthCategories
        .where(_hasSelectedObligation)
        .length;

    final familySelectedCount = familyCategories
        .where(_hasSelectedObligation)
        .length;

    final personalCareSelectedCount = personalCareCategories
        .where(_hasSelectedObligation)
        .length;

    final educationSelectedCount = educationCategories
        .where(_hasSelectedObligation)
        .length;

    final financeSelectedCount = financeCategories
        .where(_hasSelectedObligation)
        .length;

    final governmentSelectedCount = governmentCategories
        .where(_hasSelectedObligation)
        .length;

    final petsSelectedCount = petsCategories
        .where(_hasSelectedObligation)
        .length;

    final givingSelectedCount = givingCategories
        .where(_hasSelectedObligation)
        .length;

    final debtObligations = _debtObligationsById.values.toList(growable: false);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.budgetMandatoryExpensesTitle, style: AppTypography.headingMd),
        const SizedBox(height: AppSpacing.screenGap),
        MandatoryExpenseHousing(
          categories: housingCategories,
          selectedCount: housingSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.housing,
          ),
          isExpanded: _isHousingExpanded,
          onToggle: () {
            setState(() {
              _isHousingExpanded = !_isHousingExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseTransportation(
          categories: transportCategories,
          selectedCount: transportSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.transportation,
          ),
          isExpanded: _isTransportExpanded,
          onToggle: () {
            setState(() {
              _isTransportExpanded = !_isTransportExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseFood(
          categories: foodCategories,
          selectedCount: foodSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.food,
          ),
          isExpanded: _isFoodExpanded,
          onToggle: () {
            setState(() {
              _isFoodExpanded = !_isFoodExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseHealth(
          categories: healthCategories,
          selectedCount: healthSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.health,
          ),
          isExpanded: _isHealthExpanded,
          onToggle: () {
            setState(() {
              _isHealthExpanded = !_isHealthExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseFamily(
          categories: familyCategories,
          selectedCount: familySelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.family,
          ),
          isExpanded: _isFamilyExpanded,
          onToggle: () {
            setState(() {
              _isFamilyExpanded = !_isFamilyExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpensePersonalCare(
          categories: personalCareCategories,
          selectedCount: personalCareSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.personalCare,
          ),
          isExpanded: _isPersonalCareExpanded,
          onToggle: () {
            setState(() {
              _isPersonalCareExpanded = !_isPersonalCareExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseEducation(
          categories: educationCategories,
          selectedCount: educationSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.education,
          ),
          isExpanded: _isEducationExpanded,
          onToggle: () {
            setState(() {
              _isEducationExpanded = !_isEducationExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseFinance(
          categories: financeCategories,
          selectedCount: financeSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.finance,
          ),
          isExpanded: _isFinanceExpanded,
          onToggle: () {
            setState(() {
              _isFinanceExpanded = !_isFinanceExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseGovernment(
          categories: governmentCategories,
          selectedCount: governmentSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.governmentExpense,
          ),
          isExpanded: _isGovernmentExpanded,
          onToggle: () {
            setState(() {
              _isGovernmentExpanded = !_isGovernmentExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpensePets(
          categories: petsCategories,
          selectedCount: petsSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.pets,
          ),
          isExpanded: _isPetsExpanded,
          onToggle: () {
            setState(() {
              _isPetsExpanded = !_isPetsExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseGiving(
          categories: givingCategories,
          selectedCount: givingSelectedCount,
          formattedAmount: _formattedPlannedAmount(
            mandatorySummaries,
            AppCategoryGroup.giving,
          ),
          isExpanded: _isGivingExpanded,
          onToggle: () {
            setState(() {
              _isGivingExpanded = !_isGivingExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          obligationFor: _obligationFor,
          onCategoryTap: _handleCategoryTap,
        ),
        const SizedBox(height: _sectionGap),
        MandatoryExpenseDebt(
          obligations: debtObligations,
          formattedAmount: _formattedDebtPlannedAmount(debtObligations),
          isExpanded: _isDebtExpanded,
          onToggle: () {
            setState(() {
              _isDebtExpanded = !_isDebtExpanded;
            });
          },
          currencyCode: widget.currencyCode,
          onAddDebt: _openDebtEditor,
          onDebtTap: _openDebtEditor,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return content;
        }

        return SingleChildScrollView(child: content);
      },
    );
  }
}

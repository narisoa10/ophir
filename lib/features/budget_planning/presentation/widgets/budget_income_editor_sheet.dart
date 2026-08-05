import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/categories/presentation/app_category_picker.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../../core/widgets/app_editor_bottom_sheet.dart';
import '../../../../core/widgets/app_form_field_decoration.dart';
import '../../domain/entities/budget_income_source.dart';
import '../../domain/enums/budget_data_confidence.dart';
import '../../domain/enums/budget_data_source.dart';
import '../../domain/enums/budget_frequency.dart';

final class BudgetIncomeEditorResult {
  const BudgetIncomeEditorResult._({required this.isDeleted, this.income});

  const BudgetIncomeEditorResult.saved(BudgetIncomeSource income)
    : this._(isDeleted: false, income: income);

  const BudgetIncomeEditorResult.deleted() : this._(isDeleted: true);

  final bool isDeleted;
  final BudgetIncomeSource? income;
}

class BudgetIncomeEditorSheet extends StatefulWidget {
  const BudgetIncomeEditorSheet({
    required this.existingIncome,
    required this.currencyCode,
    required this.setupId,
    required this.userId,
    super.key,
  });

  final BudgetIncomeSource? existingIncome;
  final String currencyCode;
  final String setupId;
  final String userId;

  @override
  State<BudgetIncomeEditorSheet> createState() =>
      _BudgetIncomeEditorSheetState();
}

class _BudgetIncomeEditorSheetState extends State<BudgetIncomeEditorSheet> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _frequencyIntervalController;
  late final TextEditingController _timesPerYearController;
  late AppCategory _category;
  late BudgetFrequency _frequency;
  late DateTime? _nextDate;

  List<AppCategory> get _incomeCategories => AppCategories.incomeCategories;

  @override
  void initState() {
    super.initState();

    final income = widget.existingIncome;
    final categories = _incomeCategories;
    _category = _incomeCategoryFor(income?.categoryId) ?? categories.first;
    _nameController = TextEditingController(text: income?.name ?? '');
    _amountController = TextEditingController(
      text: income == null ? '' : income.amount.toStringAsFixed(2),
    );
    _frequencyIntervalController = TextEditingController(
      text: income?.frequencyInterval?.toString() ?? '',
    );
    _timesPerYearController = TextEditingController(
      text: income?.timesPerYear?.toString() ?? '',
    );
    _frequency = income?.frequency ?? BudgetFrequency.monthly;
    _nextDate = income?.nextDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _frequencyIntervalController.dispose();
    _timesPerYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppEditorBottomSheet(
      title: l10n.budgetIncomeTitle,
      formKey: _formKey,
      onSave: _save,
      saveLabel: l10n.commonSave,
      onDelete: widget.existingIncome == null
          ? null
          : () {
              Navigator.of(
                context,
              ).pop(const BudgetIncomeEditorResult.deleted());
            },
      deleteLabel: l10n.commonDelete,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: appFormFieldDecoration(
              context,
              labelText: l10n.budgetIncomeName,
            ),
            validator: _requiredTextValidator,
          ),
          const SizedBox(height: AppSpacing.itemGap),
          AppCategoryPickerField(
            categories: _incomeCategories,
            selectedCategory: _category,
            labelText: l10n.budgetIncomeType,
            onCategorySelected: (category) {
              setState(() {
                _category = category;
              });
            },
          ),
          const SizedBox(height: AppSpacing.itemGap),
          TextFormField(
            controller: _amountController,
            decoration: appFormFieldDecoration(
              context,
              labelText: '${l10n.budgetIncomeAmount} (${widget.currencyCode})',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalFormatter],
            textInputAction: TextInputAction.next,
            validator: _requiredAmountValidator,
          ),
          const SizedBox(height: AppSpacing.itemGap),
          DropdownButtonFormField<BudgetFrequency>(
            initialValue: _frequency,
            decoration: appFormFieldDecoration(
              context,
              labelText: l10n.budgetIncomeFrequency,
            ),
            items: [
              for (final frequency in BudgetFrequency.values)
                DropdownMenuItem(
                  value: frequency,
                  child: Text(_frequencyLabel(frequency, l10n)),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _frequency = value;
              });
            },
          ),
          if (_frequency == BudgetFrequency.everyNMonths) ...[
            const SizedBox(height: AppSpacing.itemGap),
            TextFormField(
              controller: _frequencyIntervalController,
              decoration: appFormFieldDecoration(
                context,
                labelText: l10n.budgetFrequencyInterval,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              validator: _requiredPositiveIntValidator,
            ),
          ],
          if (_frequency == BudgetFrequency.timesPerYear) ...[
            const SizedBox(height: AppSpacing.itemGap),
            TextFormField(
              controller: _timesPerYearController,
              decoration: appFormFieldDecoration(
                context,
                labelText: l10n.budgetTimesPerYear,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              validator: _requiredPositiveIntValidator,
            ),
          ],
          const SizedBox(height: AppSpacing.itemGap),
          FormField<DateTime>(
            initialValue: _nextDate,
            validator: (value) {
              if (_frequency == BudgetFrequency.irregular ||
                  _nextDate != null) {
                return null;
              }

              return l10n.budgetRequiredField;
            },
            builder: (field) {
              final dateText = _nextDate == null
                  ? l10n.budgetIncomeNextDate
                  : MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(_nextDate!);

              return InkWell(
                borderRadius: AppRadius.inputRadius,
                onTap: _pickNextDate,
                child: InputDecorator(
                  decoration: appFormFieldDecoration(
                    context,
                    labelText: l10n.budgetIncomeNextDate,
                  ).copyWith(errorText: field.errorText),
                  child: Text(
                    dateText,
                    style: _nextDate == null
                        ? AppTypography.body.copyWith(
                            color: context.appThemeColors.textSecondary,
                          )
                        : AppTypography.body,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickNextDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _nextDate = pickedDate;
    });

    _formKey.currentState?.validate();
  }

  AppCategory? _incomeCategoryFor(String? categoryId) {
    final category = AppCategories.byIdName(categoryId);

    if (category == null ||
        !AppCategories.incomeCategories.contains(category)) {
      return null;
    }

    return category;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final existingIncome = widget.existingIncome;
    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    final income = BudgetIncomeSource(
      id: existingIncome?.id ?? _uuid.v4(),
      setupId: existingIncome?.setupId ?? widget.setupId,
      userId: existingIncome?.userId ?? widget.userId,
      name: _nameController.text.trim(),
      categoryId: _category.id.name,
      amount: amount,
      currencyCode: existingIncome?.currencyCode.isNotEmpty == true
          ? existingIncome!.currencyCode
          : widget.currencyCode,
      frequency: _frequency,
      frequencyInterval: _frequency == BudgetFrequency.everyNMonths
          ? int.parse(_frequencyIntervalController.text.trim())
          : null,
      timesPerYear: _frequency == BudgetFrequency.timesPerYear
          ? int.parse(_timesPerYearController.text.trim())
          : null,
      nextDate: _nextDate,
      source: existingIncome?.source ?? BudgetDataSource.declared,
      confidence: existingIncome?.confidence ?? BudgetDataConfidence.estimated,
      isActive: existingIncome?.isActive ?? true,
    );

    Navigator.of(context).pop(BudgetIncomeEditorResult.saved(income));
  }

  String? _requiredTextValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return AppLocalizations.of(context).budgetRequiredField;
    }

    return null;
  }

  String? _requiredAmountValidator(String? value) {
    final text = value?.trim().replaceAll(',', '.') ?? '';
    final amount = double.tryParse(text);

    if (amount == null || amount <= 0) {
      return AppLocalizations.of(context).budgetRequiredField;
    }

    return null;
  }

  String? _requiredPositiveIntValidator(String? value) {
    final text = value?.trim() ?? '';
    final parsedValue = int.tryParse(text);

    if (parsedValue == null || parsedValue < 1) {
      return AppLocalizations.of(context).budgetRequiredField;
    }

    return null;
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

  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*[,.]?\d{0,2}'),
  );
}

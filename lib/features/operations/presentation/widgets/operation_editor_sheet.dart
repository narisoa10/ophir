import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/categories/presentation/app_category_picker.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../../core/widgets/app_editor_bottom_sheet.dart';
import '../../../../core/widgets/app_form_field_decoration.dart';
import '../../domain/entities/operation.dart';
import '../../domain/enums/operation_recurrence.dart';
import '../../domain/enums/operation_type.dart';
import '../../domain/utils/operation_calendar_date.dart';
import 'operation_editor_result.dart';
import 'operation_type_toggle.dart';

enum _OperationEditorFrequency {
  daily,
  weekly,
  biweekly,
  semiMonthly,
  monthly,
  everyNMonths,
  timesPerYear,
  yearly,
  irregular,
}

class OperationEditorSheet extends StatefulWidget {
  const OperationEditorSheet({
    this.category,
    this.operation,
    this.initialType = OperationType.expense,
    super.key,
  });

  final AppCategory? category;
  final Operation? operation;
  final OperationType initialType;

  @override
  State<OperationEditorSheet> createState() => _OperationEditorSheetState();
}

class _OperationEditorSheetState extends State<OperationEditorSheet> {
  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*[,.]?\d{0,2}'),
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _frequencyIntervalController;
  late final TextEditingController _timesPerYearController;
  late String _currencyCode;
  late _OperationEditorFrequency _frequency;
  late DateTime? _nextDate;
  late OperationType _type;
  late AppCategory _category;

  @override
  void initState() {
    super.initState();

    final operation = widget.operation;
    _type = _initialTypeFor(operation: operation, category: widget.category);
    _category =
        _categoryForType(categoryId: widget.category?.id.name, type: _type) ??
        _categoriesFor(_type).first;
    _currencyCode = operation?.currencyCode ?? 'CAD';
    _frequency = operation == null
        ? _OperationEditorFrequency.monthly
        : _frequencyFor(operation.recurrence);
    _nextDate = operationCalendarDateValue(
      operation?.occurredAt ?? DateTime.now(),
    );
    _nameController = TextEditingController(text: operation?.note ?? '');
    _amountController = TextEditingController(
      text: operation == null ? '' : operation.amount.toStringAsFixed(2),
    );
    _frequencyIntervalController = TextEditingController();
    _timesPerYearController = TextEditingController();
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
      title: _titleFor(_type, l10n),
      formKey: _formKey,
      onSave: _save,
      saveLabel: l10n.commonSave,
      onDelete: widget.operation == null
          ? null
          : () {
              Navigator.of(context).pop(const OperationEditorResult.archived());
            },
      deleteLabel: l10n.commonDelete,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OperationTypeToggle(
            isExpense: _type == OperationType.expense,
            expenseLabel: l10n.operationExpense,
            incomeLabel: l10n.operationIncome,
            onExpenseSelected: () => _selectType(OperationType.expense),
            onIncomeSelected: () => _selectType(OperationType.income),
          ),
          if (_type == OperationType.income) ...[
            const SizedBox(height: AppSpacing.itemGap),
            TextFormField(
              key: const ValueKey<String>('operation-name-field'),
              controller: _nameController,
              decoration: appFormFieldDecoration(
                context,
                labelText: l10n.operationNameHint,
              ),
              textInputAction: TextInputAction.next,
              validator: _requiredTextValidator,
            ),
          ],
          const SizedBox(height: AppSpacing.itemGap),
          KeyedSubtree(
            key: const ValueKey<String>('operation-category-field'),
            child: AppCategoryPickerField(
              key: ValueKey<String>('operation-category-picker-${_type.name}'),
              categories: _categoriesFor(_type),
              selectedCategory: _category,
              labelText: l10n.operationChooseCategory,
              onCategorySelected: (category) {
                setState(() {
                  _category = category;
                });
              },
              validator: (value) {
                if (value == null) {
                  return l10n.operationCategoryRequired;
                }

                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.itemGap),
          TextFormField(
            key: const ValueKey<String>('operation-amount-field'),
            controller: _amountController,
            decoration: appFormFieldDecoration(
              context,
              labelText: '${l10n.operationAmountHint} ($_currencyCode)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalFormatter],
            textInputAction: TextInputAction.next,
            validator: _amountValidator,
          ),
          const SizedBox(height: AppSpacing.itemGap),
          DropdownButtonFormField<_OperationEditorFrequency>(
            key: const ValueKey<String>('operation-frequency-field'),
            initialValue: _frequency,
            decoration: appFormFieldDecoration(
              context,
              labelText: l10n.budgetIncomeFrequency,
            ),
            items: [
              for (final frequency in _OperationEditorFrequency.values)
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
          if (_frequency == _OperationEditorFrequency.everyNMonths) ...[
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
          if (_frequency == _OperationEditorFrequency.timesPerYear) ...[
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
            key: const ValueKey<String>('operation-next-date-field'),
            initialValue: _nextDate,
            validator: (value) {
              if (_frequency == _OperationEditorFrequency.irregular ||
                  _nextDate != null) {
                return null;
              }

              return l10n.budgetRequiredField;
            },
            builder: (field) {
              final dateText = _nextDate == null
                  ? l10n.operationNextDate
                  : MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(_nextDate!);

              return InkWell(
                borderRadius: AppRadius.inputRadius,
                onTap: _pickNextDate,
                child: InputDecorator(
                  decoration: appFormFieldDecoration(
                    context,
                    labelText: l10n.operationNextDate,
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
    FocusScope.of(context).unfocus();
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

  void _save() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    final nameText = _type == OperationType.income
        ? _nameController.text.trim()
        : '';

    Navigator.of(context).pop(
      OperationEditorResult.saved(
        type: _type,
        amount: amount,
        currencyCode: _currencyCode,
        occurredAt: operationCalendarDateValue(_nextDate ?? DateTime.now()),
        categoryId: _category.id.name,
        recurrence: _operationRecurrenceFor(_frequency),
        note: nameText.isEmpty ? null : nameText,
      ),
    );
  }

  String? _requiredTextValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return AppLocalizations.of(context).budgetRequiredField;
    }

    return null;
  }

  String? _amountValidator(String? value) {
    final amount = double.tryParse(value?.trim().replaceAll(',', '.') ?? '');

    if (amount == null || amount <= 0) {
      return AppLocalizations.of(context).operationAmountRequired;
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

  OperationType _initialTypeFor({
    required Operation? operation,
    required AppCategory? category,
  }) {
    if (operation?.type == OperationType.income ||
        (category != null &&
            AppCategories.incomeCategories.contains(category))) {
      return OperationType.income;
    }

    return widget.initialType == OperationType.income
        ? OperationType.income
        : OperationType.expense;
  }

  _OperationEditorFrequency _frequencyFor(OperationRecurrence? recurrence) {
    return switch (recurrence) {
      OperationRecurrence.daily => _OperationEditorFrequency.daily,
      OperationRecurrence.weekly => _OperationEditorFrequency.weekly,
      OperationRecurrence.biweekly => _OperationEditorFrequency.biweekly,
      OperationRecurrence.monthly => _OperationEditorFrequency.monthly,
      OperationRecurrence.yearly => _OperationEditorFrequency.yearly,
      OperationRecurrence.none => _OperationEditorFrequency.irregular,
      null => _OperationEditorFrequency.irregular,
    };
  }

  OperationRecurrence _operationRecurrenceFor(
    _OperationEditorFrequency frequency,
  ) {
    return switch (frequency) {
      _OperationEditorFrequency.daily => OperationRecurrence.daily,
      _OperationEditorFrequency.weekly => OperationRecurrence.weekly,
      _OperationEditorFrequency.biweekly => OperationRecurrence.biweekly,
      _OperationEditorFrequency.semiMonthly => OperationRecurrence.monthly,
      _OperationEditorFrequency.monthly => OperationRecurrence.monthly,
      _OperationEditorFrequency.everyNMonths => OperationRecurrence.monthly,
      _OperationEditorFrequency.timesPerYear => OperationRecurrence.monthly,
      _OperationEditorFrequency.yearly => OperationRecurrence.yearly,
      _OperationEditorFrequency.irregular => OperationRecurrence.none,
    };
  }

  List<AppCategory> _categoriesFor(OperationType type) {
    return switch (type) {
      OperationType.expense => AppCategories.expenseCategories,
      OperationType.income => AppCategories.incomeCategories,
      OperationType.transfer => AppCategories.expenseCategories,
    };
  }

  AppCategory? _categoryForType({
    required String? categoryId,
    required OperationType type,
  }) {
    final category = AppCategories.byIdName(categoryId);

    if (category == null || !_categoriesFor(type).contains(category)) {
      return null;
    }

    return category;
  }

  void _selectType(OperationType type) {
    if (_type == type) {
      return;
    }

    setState(() {
      _type = type;
      _category = _categoriesFor(type).first;
    });
  }

  String _titleFor(OperationType type, AppLocalizations l10n) {
    return switch (type) {
      OperationType.expense => l10n.operationAddExpenseTitle,
      OperationType.income => l10n.operationAddIncomeTitle,
      OperationType.transfer => l10n.operationCreateTitle,
    };
  }

  String _frequencyLabel(
    _OperationEditorFrequency frequency,
    AppLocalizations l10n,
  ) {
    return switch (frequency) {
      _OperationEditorFrequency.daily => l10n.budgetFrequencyDaily,
      _OperationEditorFrequency.weekly => l10n.budgetFrequencyWeekly,
      _OperationEditorFrequency.biweekly => l10n.budgetFrequencyBiweekly,
      _OperationEditorFrequency.semiMonthly => l10n.budgetFrequencySemiMonthly,
      _OperationEditorFrequency.monthly => l10n.budgetFrequencyMonthly,
      _OperationEditorFrequency.everyNMonths =>
        l10n.budgetFrequencyEveryNMonths,
      _OperationEditorFrequency.timesPerYear =>
        l10n.budgetFrequencyTimesPerYear,
      _OperationEditorFrequency.yearly => l10n.budgetFrequencyYearly,
      _OperationEditorFrequency.irregular => l10n.budgetFrequencyIrregular,
    };
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../../core/widgets/app_editor_bottom_sheet.dart';
import '../../../../core/widgets/app_form_field_decoration.dart';
import '../../domain/entities/budget_obligation.dart';
import '../../domain/enums/budget_data_confidence.dart';
import '../../domain/enums/budget_data_source.dart';
import '../../domain/enums/budget_frequency.dart';

final class MandatoryExpenseEditorResult {
  const MandatoryExpenseEditorResult._({
    required this.isDeleted,
    this.obligation,
  });

  const MandatoryExpenseEditorResult.saved(BudgetObligation obligation)
    : this._(isDeleted: false, obligation: obligation);

  const MandatoryExpenseEditorResult.deleted() : this._(isDeleted: true);

  final bool isDeleted;
  final BudgetObligation? obligation;
}

class MandatoryExpenseEditorSheet extends StatefulWidget {
  const MandatoryExpenseEditorSheet({
    required this.category,
    required this.existingObligation,
    required this.currencyCode,
    required this.setupId,
    required this.userId,
    super.key,
  });

  final AppCategory category;
  final BudgetObligation? existingObligation;
  final String currencyCode;
  final String setupId;
  final String userId;

  @override
  State<MandatoryExpenseEditorSheet> createState() =>
      _MandatoryExpenseEditorSheetState();
}

class _MandatoryExpenseEditorSheetState
    extends State<MandatoryExpenseEditorSheet> {
  static const _uuid = Uuid();
  static const _livingExpenseObligationType = 'living_expense';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _frequencyIntervalController;
  late final TextEditingController _timesPerYearController;
  late BudgetFrequency _frequency;
  late DateTime? _nextDueDate;

  @override
  void initState() {
    super.initState();

    final obligation = widget.existingObligation;
    _amountController = TextEditingController(
      text: obligation == null ? '' : obligation.amount.toStringAsFixed(2),
    );
    _frequencyIntervalController = TextEditingController(
      text: obligation?.frequencyInterval?.toString() ?? '',
    );
    _timesPerYearController = TextEditingController(
      text: obligation?.timesPerYear?.toString() ?? '',
    );
    _frequency = obligation?.frequency ?? BudgetFrequency.monthly;
    _nextDueDate = obligation?.nextDueDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _frequencyIntervalController.dispose();
    _timesPerYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEditorBottomSheet(
      title: widget.category.name(l10n),
      formKey: _formKey,
      onSave: _save,
      saveLabel: l10n.commonSave,
      onDelete: widget.existingObligation == null
          ? null
          : () {
              Navigator.of(
                context,
              ).pop(const MandatoryExpenseEditorResult.deleted());
            },
      deleteLabel: l10n.commonDelete,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _amountController,
            decoration: appFormFieldDecoration(
              context,
              labelText: '${l10n.budgetExpenseAmount} (${widget.currencyCode})',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}')),
            ],
            validator: _requiredAmountValidator,
          ),
          const SizedBox(height: AppSpacing.itemGap),
          DropdownButtonFormField<BudgetFrequency>(
            initialValue: _frequency,
            decoration: appFormFieldDecoration(
              context,
              labelText: l10n.budgetExpenseFrequency,
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
              validator: _requiredPositiveIntValidator,
            ),
          ],
          const SizedBox(height: AppSpacing.itemGap),
          FormField<DateTime>(
            validator: (value) {
              if (_frequency == BudgetFrequency.irregular ||
                  _nextDueDate != null) {
                return null;
              }

              return l10n.budgetRequiredField;
            },
            builder: (field) {
              final dateText = _nextDueDate == null
                  ? l10n.budgetExpenseNextDueDate
                  : MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(_nextDueDate!);

              return InkWell(
                borderRadius: AppRadius.inputRadius,
                onTap: _pickNextDueDate,
                child: InputDecorator(
                  decoration: appFormFieldDecoration(
                    context,
                    labelText: l10n.budgetExpenseNextDueDate,
                  ).copyWith(errorText: field.errorText),
                  child: Text(
                    dateText,
                    style: _nextDueDate == null
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

  Future<void> _pickNextDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _nextDueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _nextDueDate = pickedDate;
    });

    _formKey.currentState?.validate();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final obligation = BudgetObligation(
      id: widget.existingObligation?.id ?? _uuid.v4(),
      setupId: widget.setupId,
      userId: widget.userId,
      categoryId: widget.category.id.name,
      obligationType: _livingExpenseObligationType,
      amount: double.parse(_amountController.text.trim().replaceAll(',', '.')),
      currencyCode: widget.currencyCode,
      frequency: _frequency,
      frequencyInterval: _frequency == BudgetFrequency.everyNMonths
          ? int.parse(_frequencyIntervalController.text.trim())
          : null,
      timesPerYear: _frequency == BudgetFrequency.timesPerYear
          ? int.parse(_timesPerYearController.text.trim())
          : null,
      nextDueDate: _nextDueDate,
      minimumDebtPayment: null,
      isOverdue: false,
      source: BudgetDataSource.declared,
      confidence: BudgetDataConfidence.estimated,
      isActive: true,
      note: null,
    );

    Navigator.of(context).pop(MandatoryExpenseEditorResult.saved(obligation));
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
}

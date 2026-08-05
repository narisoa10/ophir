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
import '../../domain/entities/budget_obligation.dart';
import '../../domain/enums/budget_data_confidence.dart';
import '../../domain/enums/budget_data_source.dart';
import '../../domain/enums/budget_frequency.dart';

final class MandatoryDebtEditorResult {
  const MandatoryDebtEditorResult._({required this.isDeleted, this.obligation});

  const MandatoryDebtEditorResult.saved(BudgetObligation obligation)
    : this._(isDeleted: false, obligation: obligation);

  const MandatoryDebtEditorResult.deleted() : this._(isDeleted: true);

  final bool isDeleted;
  final BudgetObligation? obligation;
}

class MandatoryDebtEditorSheet extends StatefulWidget {
  const MandatoryDebtEditorSheet({
    required this.existingObligation,
    required this.currencyCode,
    required this.setupId,
    required this.userId,
    super.key,
  });

  final BudgetObligation? existingObligation;
  final String currencyCode;
  final String setupId;
  final String userId;

  @override
  State<MandatoryDebtEditorSheet> createState() =>
      _MandatoryDebtEditorSheetState();
}

class _MandatoryDebtEditorSheetState extends State<MandatoryDebtEditorSheet> {
  static const _uuid = Uuid();
  static const _debtObligationType = 'debt_minimum';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _frequencyIntervalController;
  late final TextEditingController _timesPerYearController;
  late AppCategory _category;
  late BudgetFrequency _frequency;
  late DateTime? _nextDueDate;

  List<AppCategory> get _debtCategories => AppCategories.debtPaymentCategories;

  @override
  void initState() {
    super.initState();

    final obligation = widget.existingObligation;
    final categories = _debtCategories;
    _category =
        AppCategories.byIdName(obligation?.categoryId) ?? categories.first;
    _nameController = TextEditingController(text: obligation?.name ?? '');
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
      title: l10n.budgetDebtTitle,
      formKey: _formKey,
      onSave: _save,
      saveLabel: l10n.commonSave,
      onDelete: widget.existingObligation == null
          ? null
          : () {
              Navigator.of(
                context,
              ).pop(const MandatoryDebtEditorResult.deleted());
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
              labelText: l10n.budgetDebtName,
            ),
            validator: _requiredTextValidator,
          ),
          const SizedBox(height: AppSpacing.itemGap),
          AppCategoryPickerField(
            categories: _debtCategories,
            selectedCategory: _category,
            labelText: l10n.budgetDebtType,
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
              labelText:
                  '${l10n.budgetDebtPaymentAmount} (${widget.currencyCode})',
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
          InkWell(
            borderRadius: AppRadius.inputRadius,
            onTap: _pickNextDueDate,
            child: InputDecorator(
              decoration: appFormFieldDecoration(
                context,
                labelText: l10n.budgetDebtNextDueDate,
              ),
              child: Text(
                _nextDueDate == null
                    ? l10n.budgetDebtNextDueDate
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(_nextDueDate!),
                style: _nextDueDate == null
                    ? AppTypography.body.copyWith(
                        color: context.appThemeColors.textSecondary,
                      )
                    : AppTypography.body,
              ),
            ),
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
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    final obligation = BudgetObligation(
      id: widget.existingObligation?.id ?? _uuid.v4(),
      setupId: widget.setupId,
      userId: widget.userId,
      categoryId: _category.id.name,
      obligationType: _debtObligationType,
      amount: amount,
      currencyCode: widget.currencyCode,
      frequency: _frequency,
      frequencyInterval: _frequency == BudgetFrequency.everyNMonths
          ? int.parse(_frequencyIntervalController.text.trim())
          : null,
      timesPerYear: _frequency == BudgetFrequency.timesPerYear
          ? int.parse(_timesPerYearController.text.trim())
          : null,
      nextDueDate: _nextDueDate,
      minimumDebtPayment: amount,
      name: _nameController.text.trim(),
      isOverdue: false,
      source: BudgetDataSource.declared,
      confidence: BudgetDataConfidence.estimated,
      isActive: true,
      note: null,
    );

    Navigator.of(context).pop(MandatoryDebtEditorResult.saved(obligation));
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

    if (parsedValue == null || parsedValue <= 0) {
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

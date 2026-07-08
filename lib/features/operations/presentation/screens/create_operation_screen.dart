import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/presentation/adapters/category_presentation_adapters.dart';
import '../../controller/operation_controller.dart';
import '../../controller/operation_display_categories_provider.dart';
import '../../domain/entities/operation.dart';
import '../../domain/enums/operation_recurrence.dart';
import '../../domain/enums/operation_type.dart';
import '../adapters/operation_recurrence_adapter.dart';
import '../widgets/operation_action_tile.dart';
import '../widgets/operation_app_bar.dart';
import '../widgets/operation_text_field.dart';
import '../widgets/operation_type_toggle.dart';

typedef _SelectedCategoryContent = ({String title, String descriptionHint});

class CreateOperationScreen extends ConsumerStatefulWidget {
  const CreateOperationScreen({this.operation, super.key});

  final Operation? operation;

  @override
  ConsumerState<CreateOperationScreen> createState() =>
      _CreateOperationScreenState();
}

class _CreateOperationScreenState extends ConsumerState<CreateOperationScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isExpense = true;
  bool _isSaving = false;
  DateTime _date = DateTime.now();
  OperationRecurrence _recurrence = OperationRecurrence.none;
  String? _selectedCategoryId;
  Category? _selectedCategory;

  bool get _isEditMode => widget.operation != null;

  double? get _parsedAmount {
    return double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
  }

  String? get _trimmedNote {
    final note = _descriptionController.text.trim();
    return note.isEmpty ? null : note;
  }

  @override
  void initState() {
    super.initState();

    final operation = widget.operation;

    if (operation == null) {
      return;
    }

    _isExpense = operation.type != OperationType.income;
    _date = operation.occurredAt;
    _recurrence = operation.recurrence;
    _selectedCategoryId = operation.categoryId;
    _amountController.text = operation.amount.toStringAsFixed(2);
    _descriptionController.text = operation.note ?? '';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _date = pickedDate;
    });
  }

  Future<void> _pickCategory() async {
    final category = await context.push<Category>(
      AppRoutes.operationCategoryPicker,
      extra: _isExpense ? CategoryType.expense : CategoryType.income,
    );

    if (category == null) {
      return;
    }

    setState(() {
      _selectedCategory = category;
      _selectedCategoryId = category.id;
    });
  }

  Future<void> _pickRecurrence() async {
    final recurrence = await context.push<OperationRecurrence>(
      AppRoutes.operationRecurrencePicker,
    );

    if (recurrence == null) {
      return;
    }

    setState(() {
      _recurrence = recurrence;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final amount = _parsedAmount;

    if (amount == null || amount <= 0) {
      _showMessage(l10n.operationAmountRequired);
      return;
    }

    if (_selectedCategoryId == null) {
      _showMessage(l10n.operationCategoryRequired);
      return;
    }

    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final source = widget.operation;

    final operation = Operation(
      id: source?.id ?? '',
      userId: source?.userId ?? '',
      fromAccountId: source?.fromAccountId,
      toAccountId: source?.toAccountId,
      categoryId: _selectedCategoryId,
      type: _isExpense ? OperationType.expense : OperationType.income,
      amount: amount,
      currencyCode: source?.currencyCode ?? 'CAD',
      occurredAt: _date,
      recurrence: _recurrence,
      isRecurring: _recurrence != OperationRecurrence.none,
      note: _trimmedNote,
      createdAt: source?.createdAt ?? now,
      updatedAt: now,
    );

    final controller = ref.read(operationControllerProvider.notifier);
    final result = _isEditMode
        ? await controller.updateOperation(operation)
        : await controller.createOperation(operation);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    switch (result) {
      case Success<Operation>():
        context.pop();
      case Failure<Operation>():
        _showMessage(l10n.failureUnknown);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectExpense() {
    setState(() {
      _isExpense = true;
      _selectedCategory = null;
      _selectedCategoryId = null;
      _descriptionController.clear();
    });
  }

  _SelectedCategoryContent _selectedCategoryContent(
    AppLocalizations l10n,
    List<Category> categories,
  ) {
    const categoryAdapter = CategoryAdapter();
    final category = _selectedCategory ?? _categoryById(categories);

    if (category == null) {
      return (
        title: l10n.operationChooseCategory,
        descriptionHint: l10n.categoryExampleDefault,
      );
    }

    final presentation = categoryAdapter.toPresentation(category, l10n);

    return (title: presentation.name, descriptionHint: presentation.example);
  }

  Category? _categoryById(List<Category> categories) {
    final categoryId = _selectedCategoryId;

    if (categoryId == null) {
      return null;
    }

    for (final category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }

    return null;
  }

  void _selectIncome() {
    setState(() {
      _isExpense = false;
      _selectedCategory = null;
      _selectedCategoryId = null;
      _descriptionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = switch (ref.watch(operationDisplayCategoriesProvider)) {
      AsyncData(value: Success<List<Category>>(value: final categories)) =>
        categories,
      _ => const <Category>[],
    };
    const recurrenceAdapter = OperationRecurrenceAdapter();
    final categoryContent = _selectedCategoryContent(l10n, categories);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: OperationAppBar(
        title: _isEditMode
            ? l10n.operationEditTitle
            : l10n.operationCreateTitle,
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screen,
          children: [
            OperationTypeToggle(
              isExpense: _isExpense,
              expenseLabel: l10n.operationExpense,
              incomeLabel: l10n.operationIncome,
              onExpenseSelected: _selectExpense,
              onIncomeSelected: _selectIncome,
            ),
            const SizedBox(height: AppSpacing.screenGap),
            OperationTextField(
              controller: _amountController,
              labelText: l10n.operationAmountHint,
              hintText: '0.00',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: AppSpacing.itemGap),
            OperationActionTile(
              icon: AppIcons.operationCategory,
              title: categoryContent.title,
              onTap: _pickCategory,
            ),
            const SizedBox(height: AppSpacing.itemGap),
            OperationTextField(
              controller: _descriptionController,
              labelText: l10n.operationDescriptionHint,
              hintText: categoryContent.descriptionHint,
            ),
            const SizedBox(height: AppSpacing.itemGap),
            OperationActionTile(
              icon: AppIcons.actionCalendar,
              title: MaterialLocalizations.of(context).formatMediumDate(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: AppSpacing.itemGap),
            OperationActionTile(
              icon: AppIcons.operationRepeat,
              title: recurrenceAdapter.label(_recurrence, l10n),
              onTap: _pickRecurrence,
            ),
            const SizedBox(height: AppSpacing.screenGap),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: Text(
                  _isSaving
                      ? l10n.commonSaving
                      : _isEditMode
                      ? l10n.commonSave
                      : l10n.commonApply,
                  style: AppTypography.button,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

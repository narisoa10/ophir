import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../category_rules/controller/category_rule_controller.dart';
import '../../../category_rules/domain/utils/merchant_key.dart';
import '../../../category_rules/presentation/widgets/remember_category_rule_dialog.dart';
import '../../controller/operation_controller.dart';
import '../../controller/operation_providers.dart';
import '../../domain/entities/operation.dart';
import '../../domain/enums/operation_source.dart';
import '../../domain/enums/operation_type.dart';
import '../../domain/utils/operation_needs_categorization.dart';
import '../filters/operation_month_filter.dart';
import '../filters/operation_review_filter.dart';
import '../models/operation_date_section_presentation.dart';
import '../widgets/operation_date_section_list.dart';
import '../widgets/operation_editor_mapper.dart';
import '../widgets/operation_editor_result.dart';
import '../widgets/operation_editor_sheet.dart';
import '../widgets/operation_month_navigator.dart';
import '../widgets/operation_review_banner.dart';
import '../widgets/operations_empty_state.dart';

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({super.key});

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  bool _isEditorOpen = false;
  bool _isSavingOperation = false;
  late DateTime _selectedMonth;
  bool _reviewFilterEnabled = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyReviewFilterFromProvider();
    });
  }

  void _applyReviewFilterFromProvider() {
    if (!mounted) {
      return;
    }

    final enabled = ref.read(operationReviewFilterEnabledProvider);
    if (!enabled || _reviewFilterEnabled) {
      return;
    }

    setState(() {
      _reviewFilterEnabled = true;
    });
    ref.read(operationReviewFilterEnabledProvider.notifier).enabled = false;
  }

  Future<void> _openCreateOperationEditor() async {
    if (_isEditorOpen || _isSavingOperation) {
      return;
    }

    setState(() {
      _isEditorOpen = true;
    });

    final result = await _openOperationEditorSheet(
      initialType: OperationType.expense,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isEditorOpen = false;
    });

    if (result == null) {
      return;
    }

    await _handleOperationEditorResult(result, existingOperation: null);
  }

  Future<void> _openEditOperationEditor(
    Operation operation, {
    required List<Operation> allOperations,
  }) async {
    if (_isEditorOpen || _isSavingOperation) {
      return;
    }

    // Stage G synthetic internal transfers are read-only in the ordinary editor.
    if (operation.source == OperationSource.plaidInternalTransfer) {
      return;
    }

    final category = AppCategories.byIdName(operation.categoryId);
    if (category == null && operation.source != OperationSource.plaid) {
      return;
    }

    setState(() {
      _isEditorOpen = true;
    });

    final result = await _openOperationEditorSheet(
      existingOperation: operation,
      category: category,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isEditorOpen = false;
    });

    if (result == null) {
      return;
    }

    await _handleOperationEditorResult(result, existingOperation: operation);
  }

  Future<OperationEditorResult?> _openOperationEditorSheet({
    AppCategory? category,
    Operation? existingOperation,
    OperationType initialType = OperationType.expense,
  }) {
    return showModalBottomSheet<OperationEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return OperationEditorSheet(
          category: category,
          operation: existingOperation,
          initialType: initialType,
        );
      },
    );
  }

  Future<void> _handleOperationEditorResult(
    OperationEditorResult result, {
    required Operation? existingOperation,
  }) async {
    if (result.isArchived) {
      if (existingOperation != null) {
        await _confirmArchiveOperation(context, ref, existingOperation);
      }
      return;
    }

    await _saveOperationResult(result, existingOperation: existingOperation);
  }

  Future<void> _saveOperationResult(
    OperationEditorResult editorResult, {
    required Operation? existingOperation,
  }) async {
    if (_isSavingOperation) {
      return;
    }

    setState(() {
      _isSavingOperation = true;
    });

    final operation = operationFromEditorResult(
      result: editorResult,
      existingOperation: existingOperation,
    );
    final controller = ref.read(operationControllerProvider.notifier);
    final result = existingOperation?.source == OperationSource.plaid
        ? await controller.overridePlaidOperationCategory(
            operation: existingOperation!,
            categoryId: editorResult.categoryId,
          )
        : existingOperation == null
        ? await controller.createOperation(operation)
        : await controller.updateOperation(operation);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingOperation = false;
    });

    if (result is Failure<Operation>) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.failureUnknown)));
      return;
    }

    if (existingOperation?.source != OperationSource.plaid) {
      if (result case Success<Operation>(:final value)) {
        await _maybeRememberCategoryRule(
          savedOperation: value,
          previousOperation: existingOperation,
        );
      }
    }
  }

  Future<void> _maybeRememberCategoryRule({
    required Operation savedOperation,
    required Operation? previousOperation,
  }) async {
    if (savedOperation.categoryId == previousOperation?.categoryId) {
      return;
    }

    final merchantKey = normalizeMerchantKey(savedOperation.note);
    if (merchantKey.isEmpty) {
      return;
    }

    final category = AppCategories.byIdName(savedOperation.categoryId);
    if (category == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final choice = await showRememberCategoryRuleDialog(
      context: context,
      merchantLabel: savedOperation.note ?? merchantKey,
      category: category,
    );

    if (choice?.remember != true || !mounted) {
      return;
    }

    await ref
        .read(categoryRuleControllerProvider.notifier)
        .rememberRule(
          merchantKey: merchantKey,
          categoryId: savedOperation.categoryId!,
        );
  }

  Future<bool> _confirmArchiveOperation(
    BuildContext context,
    WidgetRef ref,
    Operation operation,
  ) async {
    if (operation.source == OperationSource.plaidInternalTransfer) {
      return false;
    }

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.operationArchiveTitle),
          content: Text(l10n.operationArchiveMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.operationArchiveConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    final result = await ref
        .read(operationControllerProvider.notifier)
        .archiveOperation(operation.id);

    if (!context.mounted) {
      return result is Success<void>;
    }

    return switch (result) {
      Success<void>() => true,
      Failure<void>() => () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failureUnknown)));
        return false;
      }(),
    };
  }

  Future<void> _refreshOperationsFromRemote() async {
    final result = await ref.read(operationRemoteSyncProvider)();

    if (!mounted) {
      return;
    }

    if (result is Failure<void>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).failureUnknown)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(operationBootstrapProvider);
    final operationsState = ref.watch(operationsProvider);
    final l10n = AppLocalizations.of(context);
    final isRefreshingOperations = bootstrapState.isLoading;

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: operationsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(l10n.failureUnknown, style: AppTypography.caption),
            ),
            data: (result) {
              return switch (result) {
                Success<List<Operation>>(:final value) => _buildOperationsBody(
                  context,
                  operations: value,
                  l10n: l10n,
                  isRefreshingOperations: isRefreshingOperations,
                ),
                Failure<List<Operation>>() =>
                  isRefreshingOperations
                      ? _buildRefreshingOperationsState()
                      : RefreshIndicator(
                          onRefresh: _refreshOperationsFromRemote,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height: constraints.maxHeight,
                                  child: const OperationsEmptyState(),
                                ),
                              );
                            },
                          ),
                        ),
              };
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.appThemeColors.primary,
        foregroundColor: context.appThemeColors.textInverse,
        onPressed: _openCreateOperationEditor,
        child: const Icon(AppIcons.actionAdd),
      ),
    );
  }

  Widget _buildOperationsBody(
    BuildContext context, {
    required List<Operation> operations,
    required AppLocalizations l10n,
    required bool isRefreshingOperations,
  }) {
    final now = DateTime.now();
    final monthFilter = OperationMonthFilter(
      selectedMonth: _selectedMonth,
      now: now,
    );
    final monthOperations = monthFilter.operationsInMonth(operations);
    final reviewFilter = OperationReviewFilter(enabled: _reviewFilterEnabled);
    final visibleOperations = reviewFilter.apply(monthOperations);
    final reviewCount = countOperationsNeedingCategorization(monthOperations);
    final monthLabel = MaterialLocalizations.of(
      context,
    ).formatMonthYear(_selectedMonth);

    if (isRefreshingOperations && !monthFilter.hasAnyOperations(operations)) {
      return _buildRefreshingOperationsState();
    }

    if (!monthFilter.hasAnyOperations(operations)) {
      return RefreshIndicator(
        onRefresh: _refreshOperationsFromRemote,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: const OperationsEmptyState(),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshOperationsFromRemote,
      child: OperationDateSectionList(
        physics: const AlwaysScrollableScrollPhysics(),
        title: l10n.operationsTitle,
        hint: l10n.operationsInteractionHint,
        periodHeader: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OperationMonthNavigator(
              monthLabel: monthLabel,
              canGoBack: monthFilter.canGoBack(operations),
              canGoForward: monthFilter.canGoForward,
              onPreviousMonth: () {
                setState(() {
                  _selectedMonth = monthFilter.previousMonth();
                });
              },
              onNextMonth: () {
                setState(() {
                  _selectedMonth = monthFilter.nextMonth();
                });
              },
              onMonthTap: () => _pickMonth(context, monthFilter, operations),
            ),
            OperationReviewBanner(
              count: reviewCount,
              label: l10n.operationsReviewBanner(reviewCount),
              filterActive: _reviewFilterEnabled,
              onToggleFilter: () {
                setState(() {
                  _reviewFilterEnabled = !_reviewFilterEnabled;
                });
              },
            ),
            if (isRefreshingOperations) ...[
              const SizedBox(height: AppSpacing.xs),
              const LinearProgressIndicator(),
            ],
          ],
        ),
        sections: visibleOperations.isEmpty
            ? const []
            : operationDateSectionsFor(visibleOperations),
        onOperationTap: (operation) {
          _openEditOperationEditor(operation, allOperations: operations);
        },
        onOperationArchive: (operation) {
          return _confirmArchiveOperation(context, ref, operation);
        },
        emptyMessage: visibleOperations.isEmpty
            ? (_reviewFilterEnabled
                  ? l10n.operationsReviewFilterEmpty
                  : l10n.operationsEmptyMonthMessage(monthLabel))
            : null,
      ),
    );
  }

  Widget _buildRefreshingOperationsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [const CircularProgressIndicator()],
      ),
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    OperationMonthFilter monthFilter,
    List<Operation> operations,
  ) async {
    final earliestMonth =
        monthFilter.earliestMonthWithOperations(operations) ??
        monthFilter.currentMonth;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: earliestMonth,
      lastDate: monthFilter.currentMonth,
      helpText: AppLocalizations.of(context).operationsPickMonth,
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedMonth = DateTime(pickedDate.year, pickedDate.month);
    });
  }
}

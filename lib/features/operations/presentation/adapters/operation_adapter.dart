import '../../../../core/icons/app_category_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/adapters/category_presentation_adapters.dart';
import '../../domain/entities/operation.dart';
import '../../domain/enums/operation_type.dart';
import '../../domain/services/operation_finance_service.dart';
import '../models/operation_date_section_presentation.dart';
import '../models/operation_list_presentation.dart';
import '../models/operation_presentation.dart';

final class OperationAdapter {
  const OperationAdapter();

  static const _defaultCurrencyCode = 'CAD';

  OperationListPresentation toListPresentation(
    List<Operation> operations,
    List<Category> categories,
    AppLocalizations l10n,
    String Function(DateTime date) formatDate,
  ) {
    const financeService = OperationFinanceService();
    final groupedOperations = _groupByDate(operations);
    final runningBalances = _runningBalancesByDate(
      groupedOperations,
      financeService,
    );

    return OperationListPresentation(
      sections: groupedOperations.entries
          .map((entry) {
            return OperationDateSectionPresentation(
              date: formatDate(entry.key),
              runningBalanceAfterDate: _formatMoney(
                runningBalances[entry.key] ?? 0,
                _currencyCode(entry.value),
                showPositiveSign: true,
              ),
              operations: entry.value
                  .map(
                    (operation) => toPresentation(operation, categories, l10n),
                  )
                  .toList(growable: false),
            );
          })
          .toList(growable: false),
    );
  }

  OperationPresentation toPresentation(
    Operation operation,
    List<Category> categories,
    AppLocalizations l10n,
  ) {
    final category = _categoryById(operation.categoryId, categories);
    final categoryPresentation = category == null
        ? null
        : const CategoryAdapter().toPresentation(category, l10n);

    return OperationPresentation(
      operation: operation,
      title:
          categoryPresentation?.uiGroupName ??
          _fallbackTitle(operation.type, l10n),
      subtitle: categoryPresentation?.name ?? '',
      amount: _formatOperationAmount(operation),
      icon:
          categoryPresentation?.icon ??
          AppCategoryIcons.fromKey(_iconKey(operation.type)),
      color:
          categoryPresentation?.color ??
          AppCategoryColors.fromKey(_colorKey(operation.type)),
      backgroundColor:
          categoryPresentation?.backgroundColor ??
          AppCategoryColors.backgroundFromKey(_colorKey(operation.type)),
    );
  }

  Category? _categoryById(String? categoryId, List<Category> categories) {
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

  String _fallbackTitle(OperationType type, AppLocalizations l10n) {
    return switch (type) {
      OperationType.expense => l10n.operationExpense,
      OperationType.income => l10n.operationIncome,
      OperationType.transfer => l10n.operationTransfer,
    };
  }

  String _iconKey(OperationType type) {
    return switch (type) {
      OperationType.expense => AppCategoryIcons.other,
      OperationType.income => AppCategoryIcons.salary,
      OperationType.transfer => AppCategoryIcons.transfer,
    };
  }

  String _colorKey(OperationType type) {
    return switch (type) {
      OperationType.expense => AppCategoryColors.red,
      OperationType.income => AppCategoryColors.green,
      OperationType.transfer => AppCategoryColors.blue,
    };
  }

  Map<DateTime, List<Operation>> _groupByDate(List<Operation> operations) {
    final groups = <DateTime, List<Operation>>{};

    for (final operation in operations) {
      final date = DateTime(
        operation.occurredAt.year,
        operation.occurredAt.month,
        operation.occurredAt.day,
      );

      groups.putIfAbsent(date, () => []).add(operation);
    }

    return groups;
  }

  Map<DateTime, double> _runningBalancesByDate(
    Map<DateTime, List<Operation>> groupedOperations,
    OperationFinanceService financeService,
  ) {
    final dates = groupedOperations.keys.toList()..sort();
    final runningBalances = <DateTime, double>{};
    var previousRunningBalance = 0.0;

    for (final date in dates) {
      final operations = groupedOperations[date] ?? const <Operation>[];
      final runningBalance = financeService.runningBalanceAfterDate(
        previousRunningBalance: previousRunningBalance,
        operations: operations,
      );

      runningBalances[date] = runningBalance;
      previousRunningBalance = runningBalance;
    }

    return runningBalances;
  }

  String _formatOperationAmount(Operation operation) {
    final signedAmount = switch (operation.type) {
      OperationType.expense => -operation.amount,
      OperationType.income => operation.amount,
      OperationType.transfer => operation.amount,
    };

    return _formatMoney(
      signedAmount,
      operation.currencyCode,
      showPositiveSign: operation.type == OperationType.income,
    );
  }

  String _formatMoney(
    double amount,
    String currencyCode, {
    required bool showPositiveSign,
  }) {
    final sign = amount > 0 && showPositiveSign ? '+' : '';
    return '$sign${amount.toStringAsFixed(2)} $currencyCode';
  }

  String _currencyCode(List<Operation> operations) {
    return operations.isEmpty
        ? _defaultCurrencyCode
        : operations.first.currencyCode;
  }
}

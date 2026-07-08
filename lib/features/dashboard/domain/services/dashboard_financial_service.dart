import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_analytics_group.dart';
import '../../../operations/domain/entities/operation.dart';
import '../../../operations/domain/enums/operation_recurrence.dart';
import '../../../operations/domain/enums/operation_type.dart';
import '../entities/dashboard_financial_summary.dart';

final class DashboardFinancialService {
  const DashboardFinancialService();

  static const _defaultCurrencyCode = 'CAD';

  DashboardFinancialSummary buildSummary({
    required List<Account> accounts,
    required List<Operation> operations,
    required List<Category> categories,
    required DateTime now,
  }) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final monthOperations = operations
        .where((operation) => _isSameMonth(operation.occurredAt, now))
        .toList(growable: false);
    final todayOperations = operations
        .where((operation) => _isSameDay(operation.occurredAt, now))
        .toList(growable: false);
    final expenseGroups = _expenseGroups(monthOperations, categoryById);
    final cashFlow = _cashFlow(monthOperations);
    final uncategorizedCount = operations
        .where(
          (operation) =>
              operation.type != OperationType.transfer &&
              operation.categoryId == null,
        )
        .length;

    return DashboardFinancialSummary(
      currencyCode: _currencyCode(accounts, operations),
      today: _today(todayOperations),
      recordedBalance: _recordedBalance(accounts, operations),
      cashFlow: cashFlow,
      expenseGroups: expenseGroups,
      insights: _insights(
        operations: operations,
        cashFlow: cashFlow,
        expenseGroups: expenseGroups,
        uncategorizedCount: uncategorizedCount,
      ),
      upcomingRecurring: _upcomingRecurring(operations, now),
      actions: _actions(
        operations: operations,
        cashFlow: cashFlow,
        expenseGroups: expenseGroups,
        uncategorizedCount: uncategorizedCount,
      ),
    );
  }

  DashboardTodaySummary _today(List<Operation> operations) {
    final income = _totalByType(operations, OperationType.income);
    final expenses = _totalByType(operations, OperationType.expense);

    return DashboardTodaySummary(
      income: income,
      expenses: expenses,
      net: income - expenses,
      operationCount: operations.length,
    );
  }

  DashboardCashFlowSummary _cashFlow(List<Operation> operations) {
    final income = _totalByType(operations, OperationType.income);
    final expenses = _totalByType(operations, OperationType.expense);

    return DashboardCashFlowSummary(
      income: income,
      expenses: expenses,
      net: income - expenses,
    );
  }

  List<DashboardExpenseGroupSummary> _expenseGroups(
    List<Operation> operations,
    Map<String, Category> categoryById,
  ) {
    final totals = <CategoryAnalyticsGroup, double>{};

    for (final operation in operations) {
      if (operation.type != OperationType.expense) {
        continue;
      }

      final category = categoryById[operation.categoryId];
      final group =
          category?.analyticsGroup ?? CategoryAnalyticsGroup.flexibleExpenses;
      totals[group] = (totals[group] ?? 0) + operation.amount;
    }

    final groups = totals.entries
        .map(
          (entry) => DashboardExpenseGroupSummary(
            analyticsGroup: entry.key,
            amount: entry.value,
          ),
        )
        .toList();

    groups.sort((a, b) => b.amount.compareTo(a.amount));
    return groups;
  }

  List<DashboardInsight> _insights({
    required List<Operation> operations,
    required DashboardCashFlowSummary cashFlow,
    required List<DashboardExpenseGroupSummary> expenseGroups,
    required int uncategorizedCount,
  }) {
    if (operations.isEmpty) {
      return const [DashboardInsight(type: DashboardInsightType.noOperations)];
    }

    final insights = <DashboardInsight>[];

    insights.add(
      DashboardInsight(
        type: cashFlow.net >= 0
            ? DashboardInsightType.positiveCashFlow
            : DashboardInsightType.negativeCashFlow,
        amount: cashFlow.net,
      ),
    );

    if (expenseGroups.isNotEmpty) {
      final topGroup = expenseGroups.first;
      insights.add(
        DashboardInsight(
          type: DashboardInsightType.topExpenseGroup,
          amount: topGroup.amount,
          analyticsGroup: topGroup.analyticsGroup,
        ),
      );
    }

    final largestOperation = _largestOperation(operations);
    if (largestOperation != null) {
      insights.add(
        DashboardInsight(
          type: DashboardInsightType.largestOperation,
          amount: largestOperation.amount,
        ),
      );
    }

    if (uncategorizedCount > 0) {
      insights.add(
        DashboardInsight(
          type: DashboardInsightType.uncategorizedOperations,
          count: uncategorizedCount,
        ),
      );
    }

    return insights.take(4).toList(growable: false);
  }

  List<DashboardRecommendedAction> _actions({
    required List<Operation> operations,
    required DashboardCashFlowSummary cashFlow,
    required List<DashboardExpenseGroupSummary> expenseGroups,
    required int uncategorizedCount,
  }) {
    if (operations.isEmpty) {
      return const [
        DashboardRecommendedAction(type: DashboardActionType.addFirstOperation),
      ];
    }

    final actions = <DashboardRecommendedAction>[];

    if (uncategorizedCount > 0) {
      actions.add(
        DashboardRecommendedAction(
          type: DashboardActionType.reviewUncategorized,
          count: uncategorizedCount,
        ),
      );
    }

    if (cashFlow.net < 0) {
      actions.add(
        DashboardRecommendedAction(
          type: DashboardActionType.checkNegativeCashFlow,
          amount: cashFlow.net,
        ),
      );
    }

    if (expenseGroups.isNotEmpty) {
      final topGroup = expenseGroups.first;
      actions.add(
        DashboardRecommendedAction(
          type: DashboardActionType.reviewTopExpenseGroup,
          amount: topGroup.amount,
          analyticsGroup: topGroup.analyticsGroup,
        ),
      );
    }

    final hasRecurring = operations.any(
      (operation) =>
          operation.isRecurring ||
          operation.recurrence != OperationRecurrence.none,
    );
    if (!hasRecurring) {
      actions.add(
        const DashboardRecommendedAction(
          type: DashboardActionType.addRecurringOperation,
        ),
      );
    }

    return actions.take(3).toList(growable: false);
  }

  List<DashboardUpcomingOperation> _upcomingRecurring(
    List<Operation> operations,
    DateTime now,
  ) {
    final upcoming = <DashboardUpcomingOperation>[];

    for (final operation in operations) {
      if (!operation.isRecurring &&
          operation.recurrence == OperationRecurrence.none) {
        continue;
      }

      final nextDate = _nextOccurrence(operation, now);
      if (nextDate == null) {
        continue;
      }

      upcoming.add(
        DashboardUpcomingOperation(operation: operation, nextDate: nextDate),
      );
    }

    upcoming.sort((a, b) => a.nextDate.compareTo(b.nextDate));
    return upcoming.take(3).toList(growable: false);
  }

  DateTime? _nextOccurrence(Operation operation, DateTime now) {
    if (operation.recurrence == OperationRecurrence.none) {
      return null;
    }

    var candidate = operation.occurredAt;
    var guard = 0;

    while (!candidate.isAfter(now) && guard < 400) {
      candidate = switch (operation.recurrence) {
        OperationRecurrence.none => candidate,
        OperationRecurrence.daily => candidate.add(const Duration(days: 1)),
        OperationRecurrence.weekly => candidate.add(const Duration(days: 7)),
        OperationRecurrence.biweekly => candidate.add(const Duration(days: 14)),
        OperationRecurrence.monthly => _addMonths(candidate, 1),
        OperationRecurrence.yearly => _addMonths(candidate, 12),
      };
      guard++;
    }

    return candidate.isAfter(now) ? candidate : null;
  }

  DateTime _addMonths(DateTime date, int months) {
    final targetMonth = date.month + months;
    final normalized = DateTime(date.year, targetMonth);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;

    return DateTime(
      normalized.year,
      normalized.month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  Operation? _largestOperation(List<Operation> operations) {
    Operation? largest;

    for (final operation in operations) {
      if (operation.type == OperationType.transfer) {
        continue;
      }

      if (largest == null || operation.amount > largest.amount) {
        largest = operation;
      }
    }

    return largest;
  }

  double _recordedBalance(List<Account> accounts, List<Operation> operations) {
    final accountIds = accounts.map((account) => account.id).toSet();
    final initialBalance = accounts.fold<double>(
      0,
      (sum, account) => sum + account.initialBalance,
    );
    var linkedNet = 0.0;
    var unlinkedNet = 0.0;

    for (final operation in operations) {
      switch (operation.type) {
        case OperationType.expense:
          if (accountIds.contains(operation.fromAccountId)) {
            linkedNet -= operation.amount;
          } else {
            unlinkedNet -= operation.amount;
          }
        case OperationType.income:
          if (accountIds.contains(operation.toAccountId)) {
            linkedNet += operation.amount;
          } else {
            unlinkedNet += operation.amount;
          }
        case OperationType.transfer:
          if (accountIds.contains(operation.fromAccountId)) {
            linkedNet -= operation.amount;
          }
          if (accountIds.contains(operation.toAccountId)) {
            linkedNet += operation.amount;
          }
      }
    }

    return initialBalance + linkedNet + unlinkedNet;
  }

  double _totalByType(List<Operation> operations, OperationType type) {
    return operations
        .where((operation) => operation.type == type)
        .fold<double>(0, (sum, operation) => sum + operation.amount);
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  bool _isSameMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
  }

  String _currencyCode(List<Account> accounts, List<Operation> operations) {
    if (accounts.isNotEmpty) {
      return accounts.first.currencyCode;
    }

    if (operations.isNotEmpty) {
      return operations.first.currencyCode;
    }

    return _defaultCurrencyCode;
  }
}

import '../../domain/entities/operation.dart';
import '../../domain/utils/operation_calendar_date.dart';
import '../../domain/services/operation_finance_service.dart';

final class OperationDateSectionPresentation {
  const OperationDateSectionPresentation({
    required this.date,
    required this.runningBalanceAfterDate,
    required this.operations,
  });

  final DateTime date;
  final double runningBalanceAfterDate;
  final List<Operation> operations;
}

List<OperationDateSectionPresentation> operationDateSectionsFor(
  List<Operation> operations,
) {
  const financeService = OperationFinanceService();
  final groupedOperations = _groupByDate(operations);
  final runningBalances = _runningBalancesByDate(
    groupedOperations,
    financeService,
  );

  return groupedOperations.entries
      .map((entry) {
        return OperationDateSectionPresentation(
          date: entry.key,
          runningBalanceAfterDate: runningBalances[entry.key] ?? 0,
          operations: entry.value,
        );
      })
      .toList(growable: false);
}

Map<DateTime, List<Operation>> _groupByDate(List<Operation> operations) {
  final groups = <DateTime, List<Operation>>{};

  for (final operation in operations) {
    final date = operationCalendarDate(operation);

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

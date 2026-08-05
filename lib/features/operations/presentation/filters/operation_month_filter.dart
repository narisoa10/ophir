import '../../domain/entities/operation.dart';
import '../../domain/utils/operation_calendar_date.dart';

final class OperationMonthFilter {
  const OperationMonthFilter({required this.selectedMonth, required this.now});

  final DateTime selectedMonth;
  final DateTime now;

  DateTime get currentMonth => DateTime(now.year, now.month);

  DateTime get selectedMonthStart =>
      DateTime(selectedMonth.year, selectedMonth.month);

  List<Operation> operationsInMonth(List<Operation> operations) {
    return operations
        .where((operation) => operationIsInMonth(operation, selectedMonth))
        .toList(growable: false);
  }

  bool get canGoForward => selectedMonthStart.isBefore(currentMonth);

  bool canGoBack(List<Operation> operations) {
    final earliestMonth = earliestMonthWithOperations(operations);

    if (earliestMonth == null) {
      return selectedMonthStart.isAfter(currentMonth);
    }

    return selectedMonthStart.isAfter(earliestMonth);
  }

  DateTime previousMonth() {
    return DateTime(selectedMonth.year, selectedMonth.month - 1);
  }

  DateTime nextMonth() {
    return DateTime(selectedMonth.year, selectedMonth.month + 1);
  }

  DateTime? earliestMonthWithOperations(List<Operation> operations) {
    if (operations.isEmpty) {
      return null;
    }

    final earliest = operations
        .map(operationCalendarDate)
        .reduce((left, right) => left.isBefore(right) ? left : right);

    return DateTime(earliest.year, earliest.month);
  }

  bool hasAnyOperations(List<Operation> operations) {
    return operations.isNotEmpty;
  }
}

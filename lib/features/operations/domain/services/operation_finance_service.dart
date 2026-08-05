import '../entities/operation.dart';
import '../enums/operation_type.dart';

final class OperationFinanceService {
  const OperationFinanceService();

  double totalBalance(List<Operation> operations) {
    return operations.fold<double>(0, _balanceAccumulator);
  }

  double dailyTotal(List<Operation> operations) {
    return operations.fold<double>(0, _balanceAccumulator);
  }

  double runningBalanceAfterDate({
    required double previousRunningBalance,
    required List<Operation> operations,
  }) {
    return previousRunningBalance + dailyTotal(operations);
  }

  double _balanceAccumulator(double sum, Operation operation) {
    return switch (operation.type) {
      OperationType.expense => sum - operation.amount,
      OperationType.income => sum + operation.amount,
      OperationType.transfer => sum,
    };
  }
}

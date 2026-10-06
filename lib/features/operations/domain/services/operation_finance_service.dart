import '../../../../core/currency/product_currency.dart';
import '../entities/operation.dart';
import '../enums/operation_type.dart';

/// Balances are amounts in [productCurrencyCode]. An operation in any other
/// currency is left out: it cannot be added without a conversion Ophir never
/// performs.
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
    if (operation.currencyCode != productCurrencyCode) {
      return sum;
    }

    return switch (operation.type) {
      OperationType.expense => sum - operation.amount,
      OperationType.income => sum + operation.amount,
      OperationType.transfer => sum,
    };
  }
}

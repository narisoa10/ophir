import '../entities/operation.dart';
import '../enums/operation_type.dart';

/// Users create and edit income and expense only. Transfers are system-only and
/// reach the app through sync; the database rejects a manual transfer
/// (operations_manual_income_expense_check).
bool isUserWritableOperation(Operation operation) {
  return switch (operation.type) {
    OperationType.income ||
    OperationType.expense => operation.toAccountId == null,
    OperationType.transfer => false,
  };
}

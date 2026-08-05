import '../entities/operation.dart';

bool operationNeedsCategorization(Operation operation) {
  return false;
}

int countOperationsNeedingCategorization(Iterable<Operation> operations) {
  return operations.where(operationNeedsCategorization).length;
}

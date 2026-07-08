import '../../../../core/errors/result.dart';
import '../entities/operation.dart';

abstract interface class OperationRepository {
  Future<Result<List<Operation>>> getOperations();

  Future<Result<Operation>> createOperation(Operation operation);

  Future<Result<Operation>> updateOperation(Operation operation);

  Future<Result<void>> archiveOperation(String operationId);
}

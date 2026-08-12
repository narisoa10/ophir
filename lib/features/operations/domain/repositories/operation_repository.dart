import '../../../../core/errors/result.dart';
import '../entities/operation.dart';

abstract interface class OperationRepository {
  Future<Result<List<Operation>>> getOperations();

  Stream<Result<List<Operation>>> watchOperations();

  Future<Result<Operation>> createOperation(Operation operation);

  Future<Result<Operation>> updateOperation(Operation operation);

  Future<Result<void>> overridePlaidOperationCategory({
    required String operationId,
    required String? categoryId,
  });

  Future<Result<void>> resetPlaidOperationCategoryOverride({
    required String operationId,
  });

  Future<Result<void>> archiveOperation(String operationId);
}

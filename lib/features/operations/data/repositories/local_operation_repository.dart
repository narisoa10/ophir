import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/operation.dart';
import '../../domain/repositories/operation_repository.dart';
import '../../domain/utils/operation_calendar_date.dart';

base class LocalOperationRepository implements OperationRepository {
  const LocalOperationRepository({
    required AppDatabase database,
    required String userId,
    Uuid uuid = const Uuid(),
  }) : _database = database,
       _userId = userId,
       _uuid = uuid;

  final AppDatabase _database;
  final String _userId;
  final Uuid _uuid;

  @override
  Future<Result<List<Operation>>> getOperations() async {
    try {
      return Success(await _database.getOperations(_userId));
    } catch (_) {
      return const Failure(DatabaseFailure());
    }
  }

  @override
  Stream<Result<List<Operation>>> watchOperations() async* {
    try {
      await for (final operations in _database.watchOperations(_userId)) {
        yield Success(operations);
      }
    } catch (_) {
      yield const Failure(DatabaseFailure());
    }
  }

  @override
  Future<Result<Operation>> createOperation(Operation operation) async {
    final now = DateTime.now().toUtc();
    final localOperation = _operationForCurrentUser(
      operation,
      id: operation.id.isEmpty ? _uuid.v4() : operation.id,
      createdAt: operation.createdAt,
      updatedAt: now,
    );

    try {
      await _database.saveOperation(localOperation);
      return Success(localOperation);
    } catch (_) {
      return const Failure(DatabaseFailure());
    }
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    final localOperation = _operationForCurrentUser(
      operation,
      id: operation.id,
      createdAt: operation.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    try {
      await _database.saveOperation(localOperation);
      return Success(localOperation);
    } catch (_) {
      return const Failure(DatabaseFailure());
    }
  }

  @override
  Future<Result<void>> overridePlaidOperationCategory({
    required String operationId,
    required String? categoryId,
  }) async {
    try {
      final operation = await _database.getOperationById(operationId);
      if (operation == null) {
        return const Failure(DatabaseFailure());
      }

      await _database.saveSyncedOperation(
        Operation(
          id: operation.id,
          userId: operation.userId,
          source: operation.source,
          externalId: operation.externalId,
          isPending: operation.isPending,
          fromAccountId: operation.fromAccountId,
          toAccountId: operation.toAccountId,
          categoryId: categoryId,
          categoryOverridden: true,
          type: operation.type,
          amount: operation.amount,
          currencyCode: operation.currencyCode,
          occurredAt: operation.occurredAt,
          recurrence: operation.recurrence,
          isRecurring: operation.isRecurring,
          note: operation.note,
          createdAt: operation.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      return const Success(null);
    } catch (_) {
      return const Failure(DatabaseFailure());
    }
  }

  @override
  Future<Result<void>> resetPlaidOperationCategoryOverride({
    required String operationId,
  }) async {
    return const Failure(DatabaseFailure());
  }

  Future<Result<Operation>> saveSyncedOperation(Operation operation) async {
    try {
      await _database.saveSyncedOperation(operation);
      return Success(operation);
    } catch (_) {
      return const Failure(DatabaseFailure());
    }
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) async {
    try {
      await _database.deleteOperation(operationId);
      return const Success(null);
    } catch (_) {
      return const Failure(DatabaseFailure());
    }
  }

  Future<void> replaceOperations(List<Operation> operations) {
    return _database.replaceOperations(_userId, operations);
  }

  Future<void> markOperationSynced(String id) {
    return _database.markOperationSynced(id);
  }

  Future<void> markOperationSyncFailed(String id) {
    return _database.markOperationSyncFailed(id);
  }

  Operation _operationForCurrentUser(
    Operation operation, {
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Operation(
      id: id,
      userId: _userId,
      fromAccountId: operation.fromAccountId,
      toAccountId: operation.toAccountId,
      categoryId: operation.categoryId,
      type: operation.type,
      amount: operation.amount,
      currencyCode: operation.currencyCode,
      occurredAt: operationCalendarDateValue(operation.occurredAt),
      recurrence: operation.recurrence,
      isRecurring: operation.isRecurring,
      note: operation.note,
      createdAt: createdAt,
      updatedAt: updatedAt,
      source: operation.source,
      externalId: operation.externalId,
      isPending: operation.isPending,
      categoryOverridden: operation.categoryOverridden,
    );
  }
}

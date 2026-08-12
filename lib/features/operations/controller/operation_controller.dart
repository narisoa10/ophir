import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/repositories/local_operation_repository.dart';
import '../domain/entities/operation.dart';
import '../domain/enums/operation_source.dart';
import 'operation_providers.dart';

final operationControllerProvider =
    AsyncNotifierProvider<OperationController, Result<List<Operation>>>(
      OperationController.new,
    );

final class OperationController extends AsyncNotifier<Result<List<Operation>>> {
  @override
  Future<Result<List<Operation>>> build() async {
    return const Success(<Operation>[]);
  }

  Future<Result<Operation>> createOperation(Operation operation) async {
    final localRepository = ref.read(localOperationRepositoryProvider);
    final result = await localRepository.createOperation(operation);

    if (result case Success<Operation>(:final value)) {
      unawaited(_syncCreatedOperation(localRepository, value));
    }

    return result;
  }

  Future<Result<Operation>> updateOperation(Operation operation) async {
    final localRepository = ref.read(localOperationRepositoryProvider);
    final result = await localRepository.updateOperation(operation);

    if (result case Success<Operation>(:final value)) {
      unawaited(_syncUpdatedOperation(localRepository, value));
    }

    return result;
  }

  Future<Result<Operation>> overridePlaidOperationCategory({
    required Operation operation,
    required String? categoryId,
  }) async {
    if (operation.source != OperationSource.plaid) {
      return const Failure(DatabaseFailure());
    }

    final remoteRepository = ref.read(remoteOperationRepositoryProvider);
    final remoteResult = await remoteRepository.overridePlaidOperationCategory(
      operationId: operation.id,
      categoryId: categoryId,
    );

    if (remoteResult is Failure<void>) {
      return Failure(remoteResult.failure);
    }

    final now = DateTime.now().toUtc();
    final updated = Operation(
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
      updatedAt: now,
    );

    final localRepository = ref.read(localOperationRepositoryProvider);
    return localRepository.saveSyncedOperation(updated);
  }

  Future<Result<void>> archiveOperation(String operationId) async {
    final localRepository = ref.read(localOperationRepositoryProvider);
    final remoteRepository = ref.read(remoteOperationRepositoryProvider);
    final result = await localRepository.archiveOperation(operationId);

    if (result is Success<void>) {
      unawaited(remoteRepository.archiveOperation(operationId));
    }

    return result;
  }

  Future<void> refresh() async {
    if (!state.hasValue) {
      state = const AsyncLoading();
    }

    state = await AsyncValue.guard(() async {
      final repository = ref.read(localOperationRepositoryProvider);
      return repository.getOperations();
    });
  }

  Future<void> _syncCreatedOperation(
    LocalOperationRepository localRepository,
    Operation operation,
  ) async {
    try {
      final remoteRepository = ref.read(remoteOperationRepositoryProvider);
      final remoteResult = await remoteRepository.createOperation(operation);

      if (remoteResult is Success<Operation>) {
        await localRepository.markOperationSynced(operation.id);
      } else {
        await localRepository.markOperationSyncFailed(operation.id);
      }
    } catch (_) {
      await localRepository.markOperationSyncFailed(operation.id);
    }
  }

  Future<void> _syncUpdatedOperation(
    LocalOperationRepository localRepository,
    Operation operation,
  ) async {
    try {
      final remoteRepository = ref.read(remoteOperationRepositoryProvider);
      final remoteResult = await remoteRepository.updateOperation(operation);

      if (remoteResult is Success<Operation>) {
        await localRepository.markOperationSynced(operation.id);
      } else {
        await localRepository.markOperationSyncFailed(operation.id);
      }
    } catch (_) {
      await localRepository.markOperationSyncFailed(operation.id);
    }
  }
}

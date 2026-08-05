import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../data/repositories/local_operation_repository.dart';
import '../domain/entities/operation.dart';
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

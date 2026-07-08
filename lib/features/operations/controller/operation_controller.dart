import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/operation.dart';
import 'operation_display_categories_provider.dart';
import 'operation_providers.dart';

final operationControllerProvider =
    AsyncNotifierProvider<OperationController, Result<List<Operation>>>(
      OperationController.new,
    );

final class OperationController extends AsyncNotifier<Result<List<Operation>>> {
  @override
  Future<Result<List<Operation>>> build() async {
    final repository = ref.watch(operationRepositoryProvider);
    return repository.getOperations();
  }

  Future<Result<Operation>> createOperation(Operation operation) async {
    final repository = ref.read(operationRepositoryProvider);
    final result = await repository.createOperation(operation);

    if (result is Success<Operation>) {
      await _refreshAfterMutation();
    }

    return result;
  }

  Future<Result<Operation>> updateOperation(Operation operation) async {
    final repository = ref.read(operationRepositoryProvider);
    final result = await repository.updateOperation(operation);

    if (result is Success<Operation>) {
      await _refreshAfterMutation();
    }

    return result;
  }

  Future<Result<void>> archiveOperation(String operationId) async {
    final repository = ref.read(operationRepositoryProvider);
    final result = await repository.archiveOperation(operationId);

    if (result is Success<void>) {
      await _refreshAfterMutation();
    }

    return result;
  }

  Future<void> refresh() async {
    if (!state.hasValue) {
      state = const AsyncLoading();
    }

    state = await AsyncValue.guard(() async {
      final repository = ref.read(operationRepositoryProvider);
      return repository.getOperations();
    });
  }

  Future<void> _refreshAfterMutation() async {
    await refresh();
    ref.invalidate(operationsProvider);
    ref.invalidate(operationDisplayCategoriesProvider);
  }
}

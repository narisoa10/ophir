import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/repositories/local_operation_repository.dart';
import '../data/repositories/supabase_operation_repository.dart';
import '../domain/entities/operation.dart';
import '../domain/repositories/operation_repository.dart';

final operationUserIdProvider = Provider<String>((ref) {
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    throw StateError('Current user is required.');
  }

  return user.id;
});

final remoteOperationRepositoryProvider = Provider<OperationRepository>((ref) {
  return SupabaseOperationRepository(Supabase.instance.client);
});

final localOperationRepositoryProvider = Provider<LocalOperationRepository>((
  ref,
) {
  return LocalOperationRepository(
    database: ref.watch(appDatabaseProvider),
    userId: ref.watch(operationUserIdProvider),
  );
});

final operationRepositoryProvider = Provider<OperationRepository>((ref) {
  return ref.watch(localOperationRepositoryProvider);
});

final operationReviewFilterEnabledProvider =
    NotifierProvider<OperationReviewFilterEnabledNotifier, bool>(
      OperationReviewFilterEnabledNotifier.new,
    );

final class OperationReviewFilterEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  set enabled(bool value) {
    state = value;
  }
}

final operationsProvider = StreamProvider<Result<List<Operation>>>((ref) {
  ref.watch(operationUserIdProvider);
  final localRepository = ref.watch(localOperationRepositoryProvider);

  return localRepository.watchOperations();
});

final operationBootstrapProvider = FutureProvider<Result<void>>((ref) async {
  final localRepository = ref.watch(localOperationRepositoryProvider);
  final remoteRepository = ref.watch(remoteOperationRepositoryProvider);

  try {
    final initial = await localRepository.getOperations();

    if (initial case Failure<List<Operation>>(:final failure)) {
      ref.invalidate(operationsProvider);
      return Failure(failure);
    }

    final remote = await remoteRepository.getOperations();

    if (remote case Failure<List<Operation>>(:final failure)) {
      ref.invalidate(operationsProvider);
      return Failure(failure);
    }

    if (remote case Success<List<Operation>>(value: final operations)) {
      await localRepository.replaceOperations(operations);
      ref.invalidate(operationsProvider);
      return const Success(null);
    }

    ref.invalidate(operationsProvider);
    return const Failure(DatabaseFailure());
  } catch (_) {
    ref.invalidate(operationsProvider);
    return const Failure(DatabaseFailure());
  }
});

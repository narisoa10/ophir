import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/repositories/local_operation_repository.dart';
import '../data/repositories/supabase_operation_repository.dart';
import '../domain/entities/operation.dart';
import '../domain/repositories/operation_repository.dart';

typedef OperationAuthUserIdReader = String? Function();

final operationUserIdProvider = Provider<String>((ref) {
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    throw StateError('Current user is required.');
  }

  return user.id;
});

/// Reads the authenticated user id at call time (not cached).
///
/// Overridable in tests so sync guards do not require a live Supabase session.
final operationAuthUserIdReaderProvider = Provider<OperationAuthUserIdReader>((
  ref,
) {
  return () => Supabase.instance.client.auth.currentUser?.id;
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

/// Per-container coordinator: one in-flight remote sync per user identity.
final operationRemoteSyncCoordinatorProvider =
    Provider<OperationRemoteSyncCoordinator>((ref) {
      return OperationRemoteSyncCoordinator();
    });

/// Shared remote snapshot → Drift reconciliation entry point.
///
/// Used by bootstrap, app resume, and pull-to-refresh.
final operationRemoteSyncProvider = Provider<Future<Result<void>> Function()>((
  ref,
) {
  return () => syncOperationsFromRemote(ref);
});

final operationBootstrapProvider = FutureProvider<Result<void>>((ref) async {
  final localRepository = ref.watch(localOperationRepositoryProvider);

  try {
    final initial = await localRepository.getOperations();

    if (initial case Failure<List<Operation>>(:final failure)) {
      ref.invalidate(operationsProvider);
      return Failure(failure);
    }

    return syncOperationsFromRemote(ref);
  } catch (_) {
    ref.invalidate(operationsProvider);
    return const Failure(DatabaseFailure());
  }
});

Future<Result<void>> syncOperationsFromRemote(Ref ref) async {
  final requestedUserId = ref.read(operationUserIdProvider);
  final localRepository = ref.read(localOperationRepositoryProvider);
  final remoteRepository = ref.read(remoteOperationRepositoryProvider);
  final readCurrentUserId = ref.read(operationAuthUserIdReaderProvider);
  final coordinator = ref.read(operationRemoteSyncCoordinatorProvider);

  return coordinator.sync(
    requestedUserId: requestedUserId,
    readCurrentUserId: readCurrentUserId,
    localRepository: localRepository,
    remoteRepository: remoteRepository,
    onAfterLocalWrite: () => ref.invalidate(operationsProvider),
  );
}

final class OperationRemoteSyncCoordinator {
  final Map<String, Future<Result<void>>> _inFlightByUser = {};

  Future<Result<void>> sync({
    required String requestedUserId,
    required OperationAuthUserIdReader readCurrentUserId,
    required LocalOperationRepository localRepository,
    required OperationRepository remoteRepository,
    required void Function() onAfterLocalWrite,
  }) {
    final existing = _inFlightByUser[requestedUserId];
    if (existing != null) {
      return existing;
    }

    late final Future<Result<void>> started;
    started = _run(
      requestedUserId: requestedUserId,
      readCurrentUserId: readCurrentUserId,
      localRepository: localRepository,
      remoteRepository: remoteRepository,
      onAfterLocalWrite: onAfterLocalWrite,
    );

    _inFlightByUser[requestedUserId] = started;

    unawaited(
      started.whenComplete(() {
        if (identical(_inFlightByUser[requestedUserId], started)) {
          _inFlightByUser.remove(requestedUserId);
        }
      }),
    );

    return started;
  }

  Future<Result<void>> _run({
    required String requestedUserId,
    required OperationAuthUserIdReader readCurrentUserId,
    required LocalOperationRepository localRepository,
    required OperationRepository remoteRepository,
    required void Function() onAfterLocalWrite,
  }) async {
    try {
      final remote = await remoteRepository.getOperations();

      if (remote case Failure<List<Operation>>(:final failure)) {
        onAfterLocalWrite();
        return Failure(failure);
      }

      if (remote case Success<List<Operation>>(value: final operations)) {
        final currentUserId = readCurrentUserId();
        if (currentUserId == null || currentUserId != requestedUserId) {
          return const Failure(UnauthorizedFailure());
        }

        await localRepository.replaceOperations(operations);
        onAfterLocalWrite();
        return const Success(null);
      }

      onAfterLocalWrite();
      return const Failure(DatabaseFailure());
    } catch (_) {
      onAfterLocalWrite();
      return const Failure(DatabaseFailure());
    }
  }
}

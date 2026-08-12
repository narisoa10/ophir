import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/database/app_database_provider.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';

void main() {
  group('Operation remote sync', () {
    test('updates synced local amount from remote snapshot', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveSyncedOperation(_operation(id: 'op-1', amount: 4.33));
      final remote = _FakeRemoteOperationRepository(
        getResult: Success([_operation(id: 'op-1', amount: 4.34)]),
      );
      final container = _container(
        database: database,
        remote: remote,
        userId: 'user-1',
      );
      addTearDown(container.dispose);

      final result = await container.read(operationRemoteSyncProvider)();
      final stored = await database.getOperationById('op-1');

      expect(result, isA<Success<void>>());
      expect(remote.getCalls, 1);
      expect(stored?.amount, 4.34);
      expect(await database.getOperations('user-1'), hasLength(1));
    });

    test('does not overwrite pending local row', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'pending-1', amount: 10));
      final remote = _FakeRemoteOperationRepository(
        getResult: Success([_operation(id: 'pending-1', amount: 99)]),
      );
      final container = _container(
        database: database,
        remote: remote,
        userId: 'user-1',
      );
      addTearDown(container.dispose);

      await container.read(operationRemoteSyncProvider)();
      final stored = await database.getOperationById('pending-1');

      expect(stored?.amount, 10);
    });

    test('does not overwrite failed local row', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'failed-1', amount: 10));
      await database.markOperationSyncFailed('failed-1');
      final remote = _FakeRemoteOperationRepository(
        getResult: Success([_operation(id: 'failed-1', amount: 99)]),
      );
      final container = _container(
        database: database,
        remote: remote,
        userId: 'user-1',
      );
      addTearDown(container.dispose);

      await container.read(operationRemoteSyncProvider)();
      final stored = await database.getOperationById('failed-1');

      expect(stored?.amount, 10);
    });

    test('removes synced local row missing remotely', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveSyncedOperation(_operation(id: 'gone', amount: 4.34));
      final remote = _FakeRemoteOperationRepository(
        getResult: const Success(<Operation>[]),
      );
      final container = _container(
        database: database,
        remote: remote,
        userId: 'user-1',
      );
      addTearDown(container.dispose);

      await container.read(operationRemoteSyncProvider)();

      expect(await database.getOperationById('gone'), isNull);
    });

    test('restores same id from remote snapshot without duplicate', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final remote = _FakeRemoteOperationRepository(
        getResult: Success([_operation(id: 'restored', amount: 4.34)]),
      );
      final container = _container(
        database: database,
        remote: remote,
        userId: 'user-1',
      );
      addTearDown(container.dispose);

      await container.read(operationRemoteSyncProvider)();
      await container.read(operationRemoteSyncProvider)();
      final operations = await database.getOperations('user-1');

      expect(operations, hasLength(1));
      expect(operations.single.id, 'restored');
      expect(operations.single.amount, 4.34);
    });

    test('remote failure keeps local rows', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveSyncedOperation(_operation(id: 'local-1', amount: 1));
      final remote = _FakeRemoteOperationRepository(
        getResult: const Failure(DatabaseFailure()),
      );
      final container = _container(
        database: database,
        remote: remote,
        userId: 'user-1',
      );
      addTearDown(container.dispose);

      final result = await container.read(operationRemoteSyncProvider)();
      final stored = await database.getOperationById('local-1');

      expect(result, isA<Failure<void>>());
      expect(stored?.amount, 1);
    });

    test('same-user concurrent syncs share one remote call', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final remoteStarted = Completer<void>();
      final remote = _FakeRemoteOperationRepository(
        getCompleter: Completer<Result<List<Operation>>>(),
        getStarted: remoteStarted,
      );
      final container = _container(
        database: database,
        remote: remote,
        userId: 'user-1',
      );
      addTearDown(container.dispose);

      final first = container.read(operationRemoteSyncProvider)();
      await remoteStarted.future;
      final second = container.read(operationRemoteSyncProvider)();

      remote.getCompleter!.complete(
        Success([_operation(id: 'op-1', amount: 4.34)]),
      );

      final results = await Future.wait([first, second]);

      expect(remote.getCalls, 1);
      expect(results.every((result) => result is Success<void>), isTrue);
      expect((await database.getOperationById('op-1'))?.amount, 4.34);
    });

    test('stale user response does not write after auth change', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveSyncedOperation(
        _operation(id: 'a-op', amount: 1, userId: 'user-a'),
      );
      final remoteStarted = Completer<void>();
      final remote = _FakeRemoteOperationRepository(
        getCompleter: Completer<Result<List<Operation>>>(),
        getStarted: remoteStarted,
      );
      var authUserId = 'user-a';
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          operationUserIdProvider.overrideWith((ref) => authUserId),
          operationAuthUserIdReaderProvider.overrideWithValue(() => authUserId),
          remoteOperationRepositoryProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      final staleSync = container.read(operationRemoteSyncProvider)();
      await remoteStarted.future;
      authUserId = 'user-b';

      remote.getCompleter!.complete(
        Success([_operation(id: 'a-op', amount: 99, userId: 'user-a')]),
      );

      final result = await staleSync;
      final stored = await database.getOperationById('a-op');

      expect(result, isA<Failure<void>>());
      expect(stored?.amount, 1);
    });

    test('different user sync is not coalesced with stale sync', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final remoteAStarted = Completer<void>();
      final remoteA = _FakeRemoteOperationRepository(
        getCompleter: Completer<Result<List<Operation>>>(),
        getStarted: remoteAStarted,
      );
      final remoteB = _FakeRemoteOperationRepository(
        getResult: Success([
          _operation(id: 'b-op', amount: 2, userId: 'user-b'),
        ]),
      );
      var authUserId = 'user-a';
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          operationUserIdProvider.overrideWith((ref) => authUserId),
          operationAuthUserIdReaderProvider.overrideWithValue(() => authUserId),
          remoteOperationRepositoryProvider.overrideWith((ref) {
            return authUserId == 'user-a' ? remoteA : remoteB;
          }),
        ],
      );
      addTearDown(container.dispose);

      final syncA = container.read(operationRemoteSyncProvider)();
      await remoteAStarted.future;

      authUserId = 'user-b';
      container.invalidate(operationUserIdProvider);
      container.invalidate(localOperationRepositoryProvider);
      container.invalidate(remoteOperationRepositoryProvider);

      final syncB = container.read(operationRemoteSyncProvider)();
      final resultB = await syncB;

      remoteA.getCompleter!.complete(
        Success([_operation(id: 'a-op', amount: 1, userId: 'user-a')]),
      );
      final resultA = await syncA;

      expect(resultB, isA<Success<void>>());
      expect(resultA, isA<Failure<void>>());
      expect(await database.getOperationById('b-op'), isNotNull);
      expect(await database.getOperationById('a-op'), isNull);
      expect(remoteA.getCalls, 1);
      expect(remoteB.getCalls, 1);
    });

    test('bootstrap reuses centralized remote sync', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final remote = _FakeRemoteOperationRepository(
        getResult: Success([_operation(id: 'boot-1', amount: 4.34)]),
      );
      final container = _container(
        database: database,
        remote: remote,
        userId: 'user-1',
      );
      addTearDown(container.dispose);

      final result = await container.read(operationBootstrapProvider.future);

      expect(result, isA<Success<void>>());
      expect(remote.getCalls, 1);
      expect((await database.getOperationById('boot-1'))?.amount, 4.34);
    });
  });
}

ProviderContainer _container({
  required AppDatabase database,
  required _FakeRemoteOperationRepository remote,
  required String userId,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      operationUserIdProvider.overrideWithValue(userId),
      operationAuthUserIdReaderProvider.overrideWithValue(() => userId),
      remoteOperationRepositoryProvider.overrideWithValue(remote),
    ],
  );
}

final class _FakeRemoteOperationRepository implements OperationRepository {
  _FakeRemoteOperationRepository({
    Result<List<Operation>>? getResult,
    this.getCompleter,
    this.getStarted,
  }) : getResult = getResult ?? const Success(<Operation>[]);

  final Result<List<Operation>> getResult;
  final Completer<Result<List<Operation>>>? getCompleter;
  final Completer<void>? getStarted;
  int getCalls = 0;

  @override
  Future<Result<List<Operation>>> getOperations() async {
    getCalls += 1;
    if (getStarted != null && !getStarted!.isCompleted) {
      getStarted!.complete();
    }

    if (getCompleter != null) {
      return getCompleter!.future;
    }

    return getResult;
  }

  @override
  Stream<Result<List<Operation>>> watchOperations() {
    return Stream.value(getResult);
  }

  @override
  Future<Result<Operation>> createOperation(Operation operation) async {
    return Success(operation);
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    return Success(operation);
  }

  @override
  Future<Result<void>> overridePlaidOperationCategory({
    required String operationId,
    required String? categoryId,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> resetPlaidOperationCategoryOverride({
    required String operationId,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) async {
    return const Success(null);
  }
}

Operation _operation({
  required String id,
  double amount = 100,
  String userId = 'user-1',
  OperationSource source = OperationSource.manual,
}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: id,
    userId: userId,
    source: source,
    fromAccountId: 'account-1',
    categoryId: AppCategoryId.expenseFoodGroceries.name,
    type: OperationType.expense,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
  );
}

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/database/app_database_provider.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/operations/controller/operation_controller.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';

void main() {
  group('OperationController local-first', () {
    test('create saves to Drift before Supabase completes', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final remote = _FakeRemoteOperationRepository(
        createCompleter: Completer<Result<Operation>>(),
      );
      final container = _container(database: database, remote: remote);
      addTearDown(container.dispose);

      final result = await container
          .read(operationControllerProvider.notifier)
          .createOperation(_operation(id: '', amount: 10));

      var operations = await database.getOperations('user-1');
      expect(operations, hasLength(1));
      expect(
        operations.single.categoryId,
        AppCategoryId.expenseFoodGroceries.name,
      );

      remote.createCompleter!.complete(Success(operations.single));
      operations = await database.getOperations('user-1');

      expect(result, isA<Success<Operation>>());
      expect(remote.createCalls, 1);
      expect(operations, hasLength(1));
    });

    test('offline create remote failure still returns local success', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final remote = _FakeRemoteOperationRepository(
        createResult: const Failure(DatabaseFailure()),
      );
      final container = _container(database: database, remote: remote);
      addTearDown(container.dispose);

      final result = await container
          .read(operationControllerProvider.notifier)
          .createOperation(_operation(id: '', amount: 10));
      final operations = await database.getOperations('user-1');

      expect(result, isA<Success<Operation>>());
      expect(remote.createCalls, 1);
      expect(operations, hasLength(1));
    });

    test('remote provider error does not fail local creation', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          operationUserIdProvider.overrideWithValue('user-1'),
          operationAuthUserIdReaderProvider.overrideWithValue(() => 'user-1'),
          remoteOperationRepositoryProvider.overrideWith((ref) {
            throw StateError('Remote unavailable');
          }),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(operationControllerProvider.notifier)
          .createOperation(_operation(id: '', amount: 10));
      final operations = await database.getOperations('user-1');

      expect(result, isA<Success<Operation>>());
      expect(operations, hasLength(1));
    });

    test(
      'operationsProvider emits local Drift data without Supabase',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await database.saveOperation(_operation(id: 'local-1'));
        final remote = _FakeRemoteOperationRepository(
          getResult: const Failure(DatabaseFailure()),
        );
        final container = _container(database: database, remote: remote);
        addTearDown(container.dispose);

        final result = await _readFirstOperations(container);

        expect(remote.getCalls, 0);
        expect(_operationsFrom(result).map((operation) => operation.id), [
          'local-1',
        ]);
      },
    );

    test(
      'operationsProvider emits empty Drift list without Supabase',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final remote = _FakeRemoteOperationRepository(
          getResult: const Success(<Operation>[]),
        );
        final container = _container(database: database, remote: remote);
        addTearDown(container.dispose);

        final result = await _readFirstOperations(container);

        expect(remote.getCalls, 0);
        expect(_operationsFrom(result), isEmpty);
      },
    );

    test('bootstrap merges Supabase data when Drift is not empty', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'local-1'));
      final remote = _FakeRemoteOperationRepository(
        getResult: Success([_operation(id: 'remote-1')]),
      );
      final container = _container(database: database, remote: remote);
      addTearDown(container.dispose);

      final result = await container.read(operationBootstrapProvider.future);
      final localOperations = await database.getOperations('user-1');

      expect(result, isA<Success<void>>());
      expect(remote.getCalls, 1);
      expect(
        localOperations.map((operation) => operation.id),
        unorderedEquals(['local-1', 'remote-1']),
      );
    });

    test(
      'bootstrap remote empty does not clear operation created during request',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final remoteStarted = Completer<void>();
        final remote = _FakeRemoteOperationRepository(
          getCompleter: Completer<Result<List<Operation>>>(),
          getStarted: remoteStarted,
          createCompleter: Completer<Result<Operation>>(),
        );
        final container = _container(database: database, remote: remote);
        addTearDown(container.dispose);

        final bootstrap = container.read(operationBootstrapProvider.future);
        await remoteStarted.future;
        expect(remote.getCalls, 1);

        final created = await container
            .read(operationControllerProvider.notifier)
            .createOperation(_operation(id: 'created-during-startup'));
        expect(created, isA<Success<Operation>>());

        remote.getCompleter!.complete(const Success(<Operation>[]));
        final result = await bootstrap;
        final localOperations = await database.getOperations('user-1');

        expect(result, isA<Success<void>>());
        expect(localOperations.map((operation) => operation.id), [
          'created-during-startup',
        ]);

        remote.createCompleter!.complete(Success(localOperations.single));
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'bootstrap loads remote when Drift is empty and stores locally',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final remote = _FakeRemoteOperationRepository(
          getResult: Success([_operation(id: 'remote-1')]),
        );
        final container = _container(database: database, remote: remote);
        addTearDown(container.dispose);

        final result = await container.read(operationBootstrapProvider.future);
        final localOperations = await database.getOperations('user-1');

        expect(remote.getCalls, 1);
        expect(result, isA<Success<void>>());
        expect(localOperations.map((operation) => operation.id), ['remote-1']);
      },
    );

    test(
      'remote Failure does not block operationsProvider empty list',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final remote = _FakeRemoteOperationRepository(
          getResult: const Failure(DatabaseFailure()),
        );
        final container = _container(database: database, remote: remote);
        addTearDown(container.dispose);

        final operations = await _readFirstOperations(container);
        final bootstrap = await container.read(
          operationBootstrapProvider.future,
        );

        expect(_operationsFrom(operations), isEmpty);
        expect(bootstrap, isA<Failure<void>>());
        expect(remote.getCalls, 1);
      },
    );

    test('bootstrap refreshes operationsProvider after remote sync', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'local-1'));
      await database.markOperationSynced('local-1');
      final remote = _FakeRemoteOperationRepository(
        getResult: Success([_operation(id: 'remote-1')]),
      );
      final container = _container(database: database, remote: remote);
      addTearDown(container.dispose);

      final updates = <Result<List<Operation>>>[];
      final subscription = container
          .listen<AsyncValue<Result<List<Operation>>>>(operationsProvider, (
            _,
            next,
          ) {
            if (next.hasValue && next.value != null) {
              updates.add(next.value!);
            }
          }, fireImmediately: true);
      addTearDown(subscription.close);

      final bootstrap = await container.read(operationBootstrapProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(bootstrap, isA<Success<void>>());
      expect(updates, isNotEmpty);
      expect(_operationsFrom(updates.last).map((operation) => operation.id), [
        'remote-1',
      ]);
      final localOperations = await database.getOperations('user-1');
      expect(localOperations.map((operation) => operation.id), ['remote-1']);
    });

    test('remote Failure does not clear local operations', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(_operation(id: 'local-1'));
      final remote = _FakeRemoteOperationRepository(
        getResult: const Failure(DatabaseFailure()),
      );
      final container = _container(database: database, remote: remote);
      addTearDown(container.dispose);

      final bootstrap = await container.read(operationBootstrapProvider.future);
      final localOperations = await database.getOperations('user-1');

      expect(bootstrap, isA<Failure<void>>());
      expect(localOperations.map((operation) => operation.id), ['local-1']);
    });

    test('legacy operation with null categoryId does not fail', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.saveOperation(
        _operation(
          id: 'transfer-1',
          type: OperationType.transfer,
          categoryId: null,
          toAccountId: 'account-2',
        ),
      );
      final remote = _FakeRemoteOperationRepository();
      final container = _container(database: database, remote: remote);
      addTearDown(container.dispose);

      final result = await _readFirstOperations(container);

      expect(_operationsFrom(result).single.categoryId, isNull);
    });

    test(
      'Plaid category override is remote-first and stores synced local row',
      () async {
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final existing = _operation(
          id: 'plaid-1',
          source: OperationSource.plaid,
          categoryId: AppCategoryId.expenseFoodGroceries.name,
        );
        await database.saveSyncedOperation(existing);
        final remote = _FakeRemoteOperationRepository();
        final container = _container(database: database, remote: remote);
        addTearDown(container.dispose);

        final result = await container
            .read(operationControllerProvider.notifier)
            .overridePlaidOperationCategory(
              operation: existing,
              categoryId: AppCategoryId.expenseFoodRestaurant.name,
            );
        final stored = await database.getOperationById('plaid-1');

        expect(result, isA<Success<Operation>>());
        expect(remote.plaidOverrideCalls, 1);
        expect(remote.updateCalls, 0);
        expect(stored?.categoryId, AppCategoryId.expenseFoodRestaurant.name);
        expect(stored?.categoryOverridden, isTrue);
        expect(stored?.source, OperationSource.plaid);
      },
    );

    test('Plaid category override can intentionally clear category', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final existing = _operation(
        id: 'plaid-1',
        source: OperationSource.plaid,
        categoryId: AppCategoryId.expenseFoodGroceries.name,
      );
      await database.saveSyncedOperation(existing);
      final remote = _FakeRemoteOperationRepository();
      final container = _container(database: database, remote: remote);
      addTearDown(container.dispose);

      final result = await container
          .read(operationControllerProvider.notifier)
          .overridePlaidOperationCategory(
            operation: existing,
            categoryId: null,
          );
      final stored = await database.getOperationById('plaid-1');

      expect(result, isA<Success<Operation>>());
      expect(remote.plaidOverrideCategoryId, isNull);
      expect(stored?.categoryId, isNull);
      expect(stored?.categoryOverridden, isTrue);
    });
  });
}

ProviderContainer _container({
  required AppDatabase database,
  required _FakeRemoteOperationRepository remote,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      operationUserIdProvider.overrideWithValue('user-1'),
      operationAuthUserIdReaderProvider.overrideWithValue(() => 'user-1'),
      remoteOperationRepositoryProvider.overrideWithValue(remote),
    ],
  );
}

Future<Result<List<Operation>>> _readFirstOperations(
  ProviderContainer container,
) {
  final completer = Completer<Result<List<Operation>>>();
  ProviderSubscription<AsyncValue<Result<List<Operation>>>>? subscription;

  subscription = container.listen<AsyncValue<Result<List<Operation>>>>(
    operationsProvider,
    (_, next) {
      final value = next.value;

      if (next.hasValue && value != null) {
        if (!completer.isCompleted) {
          completer.complete(value);
          subscription?.close();
        }
      } else if (next.hasError && !completer.isCompleted) {
        completer.completeError(next.error!, next.stackTrace);
        subscription?.close();
      }
    },
    fireImmediately: true,
  );

  return completer.future;
}

final class _FakeRemoteOperationRepository implements OperationRepository {
  _FakeRemoteOperationRepository({
    Result<List<Operation>>? getResult,
    this.getCompleter,
    this.getStarted,
    this.createResult,
    this.createCompleter,
  }) : getResult = getResult ?? const Success(<Operation>[]);

  final Result<List<Operation>> getResult;
  final Completer<Result<List<Operation>>>? getCompleter;
  final Completer<void>? getStarted;
  final Result<Operation>? createResult;
  final Completer<Result<Operation>>? createCompleter;
  int getCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int plaidOverrideCalls = 0;
  String? plaidOverrideCategoryId;

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
    createCalls += 1;

    if (createCompleter != null) {
      return createCompleter!.future;
    }

    return createResult ?? Success(operation);
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    updateCalls += 1;
    return Success(operation);
  }

  @override
  Future<Result<void>> overridePlaidOperationCategory({
    required String operationId,
    required String? categoryId,
  }) async {
    plaidOverrideCalls += 1;
    plaidOverrideCategoryId = categoryId;
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

List<Operation> _operationsFrom(Result<List<Operation>> result) {
  return switch (result) {
    Success<List<Operation>>(:final value) => value,
    Failure<List<Operation>>() => fail('Expected operations'),
  };
}

Operation _operation({
  required String id,
  double amount = 100,
  OperationType type = OperationType.expense,
  OperationSource source = OperationSource.manual,
  String? categoryId,
  String? toAccountId,
}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: id,
    userId: 'user-1',
    source: source,
    fromAccountId: 'account-1',
    toAccountId: toAccountId,
    categoryId: type == OperationType.transfer
        ? categoryId
        : categoryId ?? AppCategoryId.expenseFoodGroceries.name,
    type: type,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
  );
}

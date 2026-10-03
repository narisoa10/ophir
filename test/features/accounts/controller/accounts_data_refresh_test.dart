import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/accounts/controller/account_controller.dart';
import 'package:ophir/features/accounts/controller/account_providers.dart';
import 'package:ophir/features/accounts/controller/accounts_data_refresh.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_accounts_sync_service.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/entities/institution.dart';
import 'package:ophir/features/accounts/domain/entities/plaid_connection_health.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/accounts/domain/repositories/account_repository.dart';

import '../support/plaid_test_fakes.dart';

void main() {
  group('AccountsDataRefresh', () {
    late _FakeAccountRepository repository;
    late _FakeHealthLoader health;
    late FakePlaidFunctions functions;
    late FakePlaidLink link;
    late List<String> syncCalls;
    late List<String> lifecycleCalls;
    late ProviderContainer container;

    setUp(() {
      repository = _FakeAccountRepository(
        accounts: Success([_account(balance: 100)]),
        institutions: Success([_institution(name: 'Old Bank')]),
      );
      health = _FakeHealthLoader(
        Success([_health(PlaidConnectionStatus.active)]),
      );
      functions = FakePlaidFunctions({});
      link = FakePlaidLink();
      syncCalls = <String>[];
      lifecycleCalls = <String>[];

      container = ProviderContainer(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repository),
          plaidConnectionHealthLoaderProvider.overrideWithValue(health.load),
          plaidConnectServiceProvider.overrideWithValue(
            fakeConnectService(functions, link),
          ),
          plaidAccountsSyncCallbackProvider.overrideWithValue((id) async {
            syncCalls.add(id);
            return const Success(
              PlaidAccountsSyncSummary(
                syncedAccountCount: 0,
                institutionName: null,
              ),
            );
          }),
          plaidItemDisconnectCallbackProvider.overrideWithValue((id) async {
            lifecycleCalls.add('disconnect:$id');
            return const Success(null);
          }),
          plaidItemDeleteCallbackProvider.overrideWithValue((id) async {
            lifecycleCalls.add('delete:$id');
            return const Success(null);
          }),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<void> loadAll() async {
      container.listen(accountControllerProvider, (_, _) {});
      container.listen(accountInstitutionsProvider, (_, _) {});
      container.listen(plaidConnectionHealthProvider, (_, _) {});
      await container.read(accountControllerProvider.future);
      await container.read(accountInstitutionsProvider.future);
      await container.read(plaidConnectionHealthProvider.future);
    }

    double? cachedBalance() {
      final result = container.read(accountControllerProvider).value;
      return (result as Success<List<Account>>).value.single.currentBalance;
    }

    String? cachedInstitutionName() {
      final result = container.read(accountInstitutionsProvider).value;
      return (result as Success<List<Institution>>).value.single.name;
    }

    PlaidConnectionStatus cachedStatus() {
      final result = container.read(plaidConnectionHealthProvider).value;
      return (result as Success<List<PlaidConnectionHealth>>)
          .value
          .single
          .status;
    }

    test('success replaces accounts, institutions and health', () async {
      await loadAll();
      expect(cachedBalance(), 100);
      expect(cachedInstitutionName(), 'Old Bank');
      expect(cachedStatus(), PlaidConnectionStatus.active);

      repository.accounts = Success([_account(balance: 250)]);
      repository.institutions = Success([_institution(name: 'New Bank')]);
      health.result = Success([_health(PlaidConnectionStatus.loginRequired)]);

      final result = await container.read(accountsDataRefreshProvider).refresh();

      expect(result, isA<Success<void>>());
      expect(cachedBalance(), 250);
      expect(cachedInstitutionName(), 'New Bank');
      expect(cachedStatus(), PlaidConnectionStatus.loginRequired);
    });

    test('concurrent refresh calls share one set of reads', () async {
      await loadAll();
      final accountsBefore = repository.getAccountsCalls;
      final institutionsBefore = repository.getInstitutionsCalls;
      final healthBefore = health.loadCalls;

      final gate = Completer<void>();
      repository.gate = gate;

      final refresh = container.read(accountsDataRefreshProvider);
      final first = refresh.refresh();
      final second = refresh.refresh();
      expect(identical(first, second), isTrue);

      gate.complete();
      final results = await Future.wait([first, second]);

      expect(results, everyElement(isA<Success<void>>()));
      expect(repository.getAccountsCalls, accountsBefore + 1);
      expect(repository.getInstitutionsCalls, institutionsBefore + 1);
      expect(health.loadCalls, healthBefore + 1);
    });

    test('failure keeps last-good data without destructive loading', () async {
      await loadAll();
      final accountStates = <AsyncValue<Result<List<Account>>>>[];
      final institutionStates = <AsyncValue<Result<List<Institution>>>>[];
      final healthStates = <AsyncValue<Result<List<PlaidConnectionHealth>>>>[];
      container.listen(
        accountControllerProvider,
        (_, next) => accountStates.add(next),
      );
      container.listen(
        accountInstitutionsProvider,
        (_, next) => institutionStates.add(next),
      );
      container.listen(
        plaidConnectionHealthProvider,
        (_, next) => healthStates.add(next),
      );

      repository.accounts = const Failure(NetworkFailure());
      repository.institutions = const Failure(NetworkFailure());
      health.result = const Failure(DatabaseFailure());

      final result = await container.read(accountsDataRefreshProvider).refresh();

      expect(result, isA<Failure<void>>());
      expect(cachedBalance(), 100);
      expect(cachedInstitutionName(), 'Old Bank');
      expect(cachedStatus(), PlaidConnectionStatus.active);
      expect(accountStates.whereType<AsyncLoading<Object?>>(), isEmpty);
      expect(institutionStates.whereType<AsyncLoading<Object?>>(), isEmpty);
      expect(healthStates.whereType<AsyncLoading<Object?>>(), isEmpty);
    });

    test('thrown read error is a failure and keeps last-good data', () async {
      await loadAll();
      repository.throwOnGetAccounts = true;

      final result = await container.read(accountsDataRefreshProvider).refresh();

      expect(result, isA<Failure<void>>());
      expect(cachedBalance(), 100);
    });

    test('partial failure applies successful parts but reports failure', () async {
      await loadAll();
      repository.accounts = Success([_account(balance: 250)]);
      repository.institutions = const Failure(NetworkFailure());
      health.result = Success([_health(PlaidConnectionStatus.loginRequired)]);

      final result = await container.read(accountsDataRefreshProvider).refresh();

      expect(result, isA<Failure<void>>());
      expect(
        (result as Failure<void>).failure,
        isA<NetworkFailure>(),
      );
      expect(cachedBalance(), 250);
      expect(cachedInstitutionName(), 'Old Bank');
      expect(cachedStatus(), PlaidConnectionStatus.loginRequired);
    });

    test('initial failure keeps the existing failure result', () async {
      repository.accounts = const Failure(DatabaseFailure());
      container.listen(accountControllerProvider, (_, _) {});
      final initial = await container.read(accountControllerProvider.future);
      expect(initial, isA<Failure<List<Account>>>());

      final result = await container.read(accountsDataRefreshProvider).refresh();

      expect(result, isA<Failure<void>>());
      expect(
        container.read(accountControllerProvider).value,
        isA<Failure<List<Account>>>(),
      );

      repository.accounts = Success([_account(balance: 300)]);
      final recovered = await container
          .read(accountsDataRefreshProvider)
          .refresh();

      expect(recovered, isA<Success<void>>());
      expect(cachedBalance(), 300);
    });

    test('never-loaded providers are not created by refresh', () async {
      final result = await container.read(accountsDataRefreshProvider).refresh();

      expect(result, isA<Success<void>>());
      expect(repository.getAccountsCalls, 0);
      expect(repository.getInstitutionsCalls, 0);
      expect(health.loadCalls, 0);
      expect(container.exists(accountControllerProvider), isFalse);
    });

    test('refresh makes no Edge, Link, exchange or sync call', () async {
      await loadAll();

      await container.read(accountsDataRefreshProvider).refresh();

      expect(functions.calls, isEmpty);
      expect(link.openedTokens, isEmpty);
      expect(syncCalls, isEmpty);
      expect(lifecycleCalls, isEmpty);
    });

    test('refreshAfterMutation makes no Edge, Link, sync or lifecycle call', () async {
      await loadAll();

      await container.read(accountsDataRefreshProvider).refreshAfterMutation();

      expect(functions.calls, isEmpty);
      expect(link.openedTokens, isEmpty);
      expect(syncCalls, isEmpty);
      expect(lifecycleCalls, isEmpty);
    });

    test('refreshAfterMutation without an in-flight refresh reads once', () async {
      await loadAll();
      final accountsBefore = repository.getAccountsCalls;
      repository.accounts = Success([_account(balance: 400)]);

      final result = await container
          .read(accountsDataRefreshProvider)
          .refreshAfterMutation();

      expect(result, isA<Success<void>>());
      expect(repository.getAccountsCalls, accountsBefore + 1);
      expect(cachedBalance(), 400);
    });

    test(
      'refreshAfterMutation never settles on a refresh started before it',
      () async {
        await loadAll();
        final accountsBefore = repository.getAccountsCalls;
        final healthBefore = health.loadCalls;
        final refresh = container.read(accountsDataRefreshProvider);

        // A refresh reads the pre-mutation snapshot and is held in flight.
        final gate = Completer<void>();
        repository.gate = gate;
        final stale = refresh.refresh();
        await pumpEventQueue();
        expect(repository.getAccountsCalls, accountsBefore + 1);

        // The mutation commits, then the caller asks for a post-mutation read.
        repository.gate = null;
        repository.accounts = Success([_account(balance: 999)]);
        health.result = Success([_health(PlaidConnectionStatus.loginRequired)]);
        final afterMutation = refresh.refreshAfterMutation();
        expect(identical(afterMutation, stale), isFalse);

        await pumpEventQueue();
        expect(
          repository.getAccountsCalls,
          accountsBefore + 1,
          reason: 'no new read may start while the stale one is in flight',
        );

        gate.complete();
        expect(await stale, isA<Success<void>>());
        expect(await afterMutation, isA<Success<void>>());

        expect(repository.getAccountsCalls, accountsBefore + 2);
        expect(health.loadCalls, healthBefore + 2);
        expect(cachedBalance(), 999);
        expect(cachedStatus(), PlaidConnectionStatus.loginRequired);
      },
    );

    test('concurrent refreshAfterMutation calls share one new read', () async {
      await loadAll();
      final accountsBefore = repository.getAccountsCalls;
      final refresh = container.read(accountsDataRefreshProvider);

      final gate = Completer<void>();
      repository.gate = gate;
      final stale = refresh.refresh();
      await pumpEventQueue();

      repository.gate = null;
      repository.accounts = Success([_account(balance: 500)]);
      final calls = [
        refresh.refreshAfterMutation(),
        refresh.refreshAfterMutation(),
        refresh.refreshAfterMutation(),
      ];
      expect(identical(calls[0], calls[1]), isTrue);
      expect(identical(calls[1], calls[2]), isTrue);

      gate.complete();
      await stale;
      final results = await Future.wait(calls);

      expect(results, everyElement(isA<Success<void>>()));
      expect(repository.getAccountsCalls, accountsBefore + 2);
      expect(cachedBalance(), 500);
    });

    test(
      'concurrent refreshAfterMutation calls without in-flight read once',
      () async {
        await loadAll();
        final accountsBefore = repository.getAccountsCalls;
        final refresh = container.read(accountsDataRefreshProvider);

        final results = await Future.wait([
          refresh.refreshAfterMutation(),
          refresh.refreshAfterMutation(),
        ]);

        expect(results, everyElement(isA<Success<void>>()));
        expect(repository.getAccountsCalls, accountsBefore + 1);
      },
    );

    test('a mutation after the post-mutation read began gets its own read', () async {
      await loadAll();
      final accountsBefore = repository.getAccountsCalls;
      final refresh = container.read(accountsDataRefreshProvider);

      final gate = Completer<void>();
      repository.gate = gate;
      final first = refresh.refreshAfterMutation();
      await pumpEventQueue();
      expect(repository.getAccountsCalls, accountsBefore + 1);

      repository.gate = null;
      repository.accounts = Success([_account(balance: 777)]);
      final second = refresh.refreshAfterMutation();
      expect(identical(first, second), isFalse);

      gate.complete();
      await Future.wait([first, second]);

      expect(repository.getAccountsCalls, accountsBefore + 2);
      expect(cachedBalance(), 777);
    });

    test('an in-flight refresh that throws does not stick refreshAfterMutation', () async {
      var loaderBroken = true;
      final throwing = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          accountRepositoryProvider.overrideWithValue(repository),
          plaidConnectionHealthLoaderProvider.overrideWith((ref) {
            if (loaderBroken) {
              throw StateError('loader unavailable');
            }
            return health.load;
          }),
        ],
      );
      addTearDown(throwing.dispose);
      // Health is never loaded, so nothing watches the loader provider and
      // only the refresh reads it.
      throwing.listen(accountControllerProvider, (_, _) {});
      await throwing.read(accountControllerProvider.future);
      final refresh = throwing.read(accountsDataRefreshProvider);
      final accountsBefore = repository.getAccountsCalls;

      final stale = refresh.refresh();
      final first = refresh.refreshAfterMutation();
      expect(identical(first, stale), isFalse);
      await expectLater(stale, throwsA(anything));

      // The post-mutation re-read itself still hits the broken loader.
      await expectLater(first, throwsA(anything));
      expect(repository.getAccountsCalls, accountsBefore);

      loaderBroken = false;
      throwing.invalidate(plaidConnectionHealthLoaderProvider);
      repository.accounts = Success([_account(balance: 321)]);

      final second = refresh.refreshAfterMutation();
      expect(identical(second, first), isFalse);
      expect(await second, isA<Success<void>>());
      expect(repository.getAccountsCalls, accountsBefore + 1);
      expect(
        (throwing.read(accountControllerProvider).value
                as Success<List<Account>>)
            .value
            .single
            .currentBalance,
        321,
      );

      final third = refresh.refreshAfterMutation();
      expect(identical(third, second), isFalse);
      expect(await third, isA<Success<void>>());
      expect(repository.getAccountsCalls, accountsBefore + 2);
    });

    test('refreshAfterMutation failure keeps last-good data', () async {
      await loadAll();
      final accountStates = <AsyncValue<Result<List<Account>>>>[];
      container.listen(
        accountControllerProvider,
        (_, next) => accountStates.add(next),
      );
      repository.accounts = const Failure(NetworkFailure());

      final result = await container
          .read(accountsDataRefreshProvider)
          .refreshAfterMutation();

      expect(result, isA<Failure<void>>());
      expect(cachedBalance(), 100);
      expect(accountStates.whereType<AsyncLoading<Object?>>(), isEmpty);
    });

    test('sequential refreshes apply successive snapshots', () async {
      await loadAll();
      final refresh = container.read(accountsDataRefreshProvider);

      repository.accounts = Success([_account(balance: 150)]);
      expect(await refresh.refresh(), isA<Success<void>>());
      expect(cachedBalance(), 150);

      repository.accounts = Success([_account(balance: 175)]);
      expect(await refresh.refresh(), isA<Success<void>>());
      expect(cachedBalance(), 175);
    });
  });
}

final class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({required this.accounts, required this.institutions});

  Result<List<Account>> accounts;
  Result<List<Institution>> institutions;
  Completer<void>? gate;
  bool throwOnGetAccounts = false;
  int getAccountsCalls = 0;
  int getInstitutionsCalls = 0;

  /// Captures the snapshot when the read starts, as a database read would,
  /// even if the gate holds it in flight.
  @override
  Future<Result<List<Account>>> getAccounts() async {
    getAccountsCalls += 1;
    final snapshot = accounts;
    await gate?.future;
    if (throwOnGetAccounts) {
      throw StateError('read failed');
    }
    return snapshot;
  }

  @override
  Future<Result<List<Account>>> getFinanciallyActiveAccounts() async {
    return accounts;
  }

  @override
  Future<Result<List<Institution>>> getInstitutions() async {
    getInstitutionsCalls += 1;
    final snapshot = institutions;
    await gate?.future;
    return snapshot;
  }

  @override
  Future<Result<Account>> updateAccountFinancialParticipation({
    required String accountId,
    required bool isIncludedInFinances,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeHealthLoader {
  _FakeHealthLoader(this.result);

  Result<List<PlaidConnectionHealth>> result;
  Completer<void>? gate;
  int loadCalls = 0;

  Future<Result<List<PlaidConnectionHealth>>> load() async {
    loadCalls += 1;
    final snapshot = result;
    await gate?.future;
    return snapshot;
  }
}

Account _account({required double balance}) {
  final now = DateTime(2026, 7, 23);

  return Account(
    id: 'account-1',
    userId: 'user-1',
    name: 'Checking',
    type: AccountType.bank,
    currencyCode: 'CAD',
    institutionId: 'institution-1',
    plaidItemId: 'item-1',
    plaidAccountId: 'plaid-account-1',
    mask: '1234',
    currentBalance: balance,
    iconKey: 'bank',
    colorKey: 'blue',
    sortOrder: 0,
    isArchived: false,
    isIncludedInFinances: true,
    createdAt: now,
    updatedAt: now,
  );
}

Institution _institution({required String name}) {
  final now = DateTime(2026, 7, 23);

  return Institution(
    id: 'institution-1',
    userId: 'user-1',
    plaidItemId: 'item-1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

PlaidConnectionHealth _health(PlaidConnectionStatus status) {
  return PlaidConnectionHealth(
    connectionId: 'item-1',
    status: status,
    statusReason: status == PlaidConnectionStatus.loginRequired
        ? PlaidConnectionStatusReason.loginRequired
        : null,
  );
}

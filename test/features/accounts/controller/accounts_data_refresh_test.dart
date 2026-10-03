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
    late List<String> removeCalls;
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
      removeCalls = <String>[];

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
          plaidItemRemoveCallbackProvider.overrideWithValue((id) async {
            removeCalls.add(id);
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
      expect(removeCalls, isEmpty);
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

  @override
  Future<Result<List<Account>>> getAccounts() async {
    getAccountsCalls += 1;
    await gate?.future;
    if (throwOnGetAccounts) {
      throw StateError('read failed');
    }
    return accounts;
  }

  @override
  Future<Result<List<Account>>> getFinanciallyActiveAccounts() async {
    return accounts;
  }

  @override
  Future<Result<List<Institution>>> getInstitutions() async {
    getInstitutionsCalls += 1;
    await gate?.future;
    return institutions;
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
  int loadCalls = 0;

  Future<Result<List<PlaidConnectionHealth>>> load() async {
    loadCalls += 1;
    return result;
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

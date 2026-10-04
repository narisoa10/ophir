import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/theme_v1/app_colors.dart';
import 'package:ophir/features/accounts/controller/account_providers.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_accounts_sync_service.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_connect_service.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/entities/institution.dart';
import 'package:ophir/features/accounts/domain/entities/plaid_connection_health.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/accounts/domain/repositories/account_repository.dart';
import 'package:ophir/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:ophir/features/accounts/presentation/widgets/accounts_empty_state.dart';
import 'package:ophir/core/widgets/app_compact_switch.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../../support/plaid_test_fakes.dart';

void main() {
  group('AccountsScreen', () {
    testWidgets(
      'empty accounts show title, empty state, and connect bank action',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          _TestApp(
            repository: _FakeAccountRepository(accounts: []),
            child: const AccountsScreen(),
          ),
        );
        await tester.pump();

        expect(find.text(l10n.accountsTitle), findsOneWidget);
        expect(find.byType(AccountsEmptyState), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, l10n.accountsConnectBank),
          findsOneWidget,
        );
      },
    );

    testWidgets('existing account list renders', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Test Bank'));
      await tester.pump();

      expect(find.text('Checking'), findsOneWidget);
      expect(find.byType(AccountsEmptyState), findsNothing);
      expect(
        find.widgetWithText(FilledButton, l10n.accountsConnectBank),
        findsOneWidget,
      );
    });

    testWidgets('bank groups are collapsed by default', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text('1 account'), findsOneWidget);
      expect(find.text('Checking'), findsNothing);
    });

    testWidgets('bank header shows name and aggregate balance collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text('100.00 CAD'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('bank group expands and collapses', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Test Bank'));
      await tester.pump();

      expect(find.text('Checking'), findsOneWidget);

      await tester.tap(find.text('Test Bank'));
      await tester.pump();

      expect(find.text('Checking'), findsNothing);
    });

    testWidgets('switch off shows confirmation and cancel keeps value', (
      tester,
    ) async {
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking')],
        institutions: [_institution()],
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        _TestApp(repository: repository, child: const AccountsScreen()),
      );
      await tester.pump();
      await tester.tap(find.text('Test Bank'));
      await tester.pump();

      await tester.tap(find.byType(AppCompactSwitch));
      await tester.pump();

      expect(
        find.text(l10n.accountsFinancialExclusionDialogBody),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.accountsFinancialExclusionDialogCancel));
      await tester.pumpAndSettle();

      expect(repository.accounts.single.isIncludedInFinances, isTrue);
      expect(repository.participationUpdates, isEmpty);
    });

    testWidgets('confirming switch off persists false', (tester) async {
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking')],
        institutions: [_institution()],
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        _TestApp(repository: repository, child: const AccountsScreen()),
      );
      await tester.pump();
      await tester.tap(find.text('Test Bank'));
      await tester.pump();

      await tester.tap(find.byType(AppCompactSwitch));
      await tester.pump();
      await tester.tap(find.text(l10n.accountsFinancialExclusionDialogConfirm));
      await tester.pumpAndSettle();

      expect(repository.accounts.single.isIncludedInFinances, isFalse);
      expect(
        find.text(l10n.accountsFinancialParticipationExcludedStatus),
        findsOneWidget,
      );
      expect(repository.participationUpdates, [
        const _ParticipationUpdate('account-1', false),
      ]);
    });

    testWidgets('switch on persists true without confirmation', (tester) async {
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking', isIncludedInFinances: false)],
        institutions: [_institution()],
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        _TestApp(repository: repository, child: const AccountsScreen()),
      );
      await tester.pump();
      await tester.tap(find.text('Test Bank'));
      await tester.pump();

      expect(
        find.text(l10n.accountsFinancialParticipationExcludedStatus),
        findsOneWidget,
      );

      await tester.tap(find.byType(AppCompactSwitch));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.accountsFinancialExclusionDialogBody),
        findsNothing,
      );
      expect(repository.accounts.single.isIncludedInFinances, isTrue);
      expect(
        find.text(l10n.accountsFinancialParticipationIncludedStatus),
        findsOneWidget,
      );
      expect(repository.participationUpdates, [
        const _ParticipationUpdate('account-1', true),
      ]);
    });

    testWidgets('accounts from different institutions are grouped separately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [
              _account(name: 'Checking'),
              _account(
                id: 'account-2',
                name: 'Savings',
                institutionId: 'institution-2',
                plaidItemId: 'item-2',
                plaidAccountId: 'plaid-account-2',
              ),
            ],
            institutions: [
              _institution(),
              _institution(id: 'institution-2', name: 'Second Bank'),
            ],
          ),
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text('Second Bank'), findsOneWidget);
      expect(find.text('Checking'), findsNothing);
      expect(find.text('Savings'), findsNothing);
    });

    testWidgets('financially excluded account remains visible for management', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking', isIncludedInFinances: false)],
            institutions: [_institution()],
          ),
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Test Bank'));
      await tester.pump();

      expect(find.text('Checking'), findsOneWidget);
      expect(
        tester.widget<AppCompactSwitch>(find.byType(AppCompactSwitch)).value,
        isFalse,
      );
      expect(find.text('Excluded from finances'), findsOneWidget);
    });

    testWidgets('accounts screen uses centralized compact switch', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Test Bank'));
      await tester.pump();

      expect(find.byType(AppCompactSwitch), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('sync menu uses existing sync path without changing flag', (
      tester,
    ) async {
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking', isIncludedInFinances: false)],
        institutions: [_institution()],
      );
      final syncedConnectionIds = <String>[];

      await tester.pumpWidget(
        _TestApp(
          repository: repository,
          syncAccounts: (connectionId) async {
            syncedConnectionIds.add(connectionId);
            return const Success(
              PlaidAccountsSyncSummary(syncedAccountCount: 1),
            );
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh now'));
      await tester.pumpAndSettle();

      expect(syncedConnectionIds, ['item-1']);
      expect(repository.accounts.single.isIncludedInFinances, isFalse);
      expect(repository.participationUpdates, isEmpty);
    });

    testWidgets('sync double tap starts one sync', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final completer = Completer<Result<PlaidAccountsSyncSummary>>();
      var syncCallCount = 0;

      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          syncAccounts: (connectionId) {
            syncCallCount += 1;
            return completer.future;
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuSync));
      await tester.pump();

      expect(syncCallCount, 1);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const Success(PlaidAccountsSyncSummary(syncedAccountCount: 1)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text(l10n.accountsBankMenuSync), findsOneWidget);
    });

    testWidgets('sync connection_disconnected refreshes into disconnected UI', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final store = _HealthStore([_health('item-1')]);
      final link = FakePlaidLink();

      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          healthStore: store,
          connectService: fakeConnectService(FakePlaidFunctions({}), link),
          syncAccounts: (connectionId) async {
            store.disconnect(connectionId);
            return const Failure(PlaidConnectionDisconnectedFailure());
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final healthLoadsBefore = store.loadCalls;

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuSync));
      await tester.pumpAndSettle();

      expect(store.loadCalls, greaterThan(healthLoadsBefore));
      expect(find.text(l10n.accountsDisconnectedTitle), findsOneWidget);
      expect(find.text(l10n.failureUnknown), findsNothing);
      expect(link.openedTokens, isEmpty);
    });
  });

  group('AccountsScreen Disconnect and Delete', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final disconnectedTitle = find.text(l10n.accountsDisconnectedTitle);

    Future<void> pumpLifecycle(
      WidgetTester tester, {
      required _HealthStore store,
      _FakeAccountRepository? repository,
      PlaidItemLifecycleCallback? disconnectItem,
      PlaidItemLifecycleCallback? deleteItem,
      PlaidAccountsSyncCallback? syncAccounts,
      FakePlaidLink? link,
    }) async {
      await tester.pumpWidget(
        _TestApp(
          repository:
              repository ??
              _FakeAccountRepository(
                accounts: [_account(name: 'Checking')],
                institutions: [_institution()],
              ),
          healthStore: store,
          connectService: fakeConnectService(
            FakePlaidFunctions({}),
            link ?? FakePlaidLink(),
          ),
          syncAccounts: syncAccounts ?? _successfulSync,
          disconnectItem:
              disconnectItem ?? (_) async => const Failure(UnknownFailure()),
          deleteItem: deleteItem ?? (_) async => const Failure(UnknownFailure()),
          child: const AccountsScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> chooseMenu(WidgetTester tester, String label) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('active connection menu offers sync, disconnect and delete', (
      tester,
    ) async {
      await pumpLifecycle(tester, store: _HealthStore([_health('item-1')]));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsBankMenuSync), findsOneWidget);
      expect(find.text(l10n.accountsBankMenuDisconnect), findsOneWidget);
      expect(find.text(l10n.accountsBankMenuRemoveConnection), findsOneWidget);
      final deleteText = tester.widget<Text>(
        find.text(l10n.accountsBankMenuRemoveConnection),
      );
      expect(deleteText.style?.color, AppColors.error);
    });

    testWidgets('disconnected connection menu offers only delete', (
      tester,
    ) async {
      await pumpLifecycle(
        tester,
        store: _HealthStore([
          _health('item-1', disconnectedAt: DateTime.utc(2026, 10, 3)),
        ]),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsBankMenuSync), findsNothing);
      expect(find.text(l10n.accountsBankMenuDisconnect), findsNothing);
      expect(find.text(l10n.accountsBankMenuRemoveConnection), findsOneWidget);
    });

    testWidgets('disconnected banner wins over every remaining health signal', (
      tester,
    ) async {
      final link = FakePlaidLink();
      final syncCalls = <String>[];
      await pumpLifecycle(
        tester,
        store: _HealthStore([
          _health(
            'item-1',
            status: PlaidConnectionStatus.loginRequired,
            pendingDisconnectAt: DateTime.utc(2099, 11, 15),
            disconnectedAt: DateTime.utc(2026, 10, 3),
          ),
        ]),
        link: link,
        syncAccounts: (id) async {
          syncCalls.add(id);
          return const Success(PlaidAccountsSyncSummary(syncedAccountCount: 1));
        },
      );

      expect(
        find.byKey(const ValueKey('connection-health-item-1')),
        findsOneWidget,
      );
      expect(disconnectedTitle, findsOneWidget);
      expect(find.text(l10n.accountsDisconnectedBody), findsOneWidget);
      expect(find.text(l10n.accountsReconnectRequiredTitle), findsNothing);
      expect(find.text(l10n.accountsReconnectAction), findsNothing);
      expect(find.text(l10n.accountsAccessExtensionRequired), findsNothing);
      expect(find.text(l10n.accountsExtendAccessAction), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('connection-health-item-1')),
          matching: find.byType(TextButton),
        ),
        findsNothing,
      );
      expect(link.openedTokens, isEmpty);
      expect(syncCalls, isEmpty);
    });

    testWidgets('disconnect cancel calls nothing', (tester) async {
      final calls = <String>[];
      await pumpLifecycle(
        tester,
        store: _HealthStore([_health('item-1')]),
        disconnectItem: (id) async {
          calls.add(id);
          return const Success(null);
        },
      );

      await chooseMenu(tester, l10n.accountsBankMenuDisconnect);
      expect(find.text(l10n.accountsDisconnectDialogBody), findsOneWidget);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(disconnectedTitle, findsNothing);
    });

    testWidgets('disconnect success refreshes from DB into disconnected UI', (
      tester,
    ) async {
      final store = _HealthStore([_health('item-1')]);
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking')],
        institutions: [_institution()],
      );
      final disconnectCalls = <String>[];
      final deleteCalls = <String>[];
      await pumpLifecycle(
        tester,
        store: store,
        repository: repository,
        disconnectItem: (id) async {
          disconnectCalls.add(id);
          store.disconnect(id);
          return const Success(null);
        },
        deleteItem: (id) async {
          deleteCalls.add(id);
          return const Success(null);
        },
      );
      final accountLoadsBefore = repository.getAccountsCalls;
      final healthLoadsBefore = store.loadCalls;

      await chooseMenu(tester, l10n.accountsBankMenuDisconnect);
      await tester.tap(find.text(l10n.accountsDisconnectConfirm));
      await tester.pumpAndSettle();

      expect(disconnectCalls, ['item-1']);
      expect(deleteCalls, isEmpty);
      expect(repository.getAccountsCalls, accountLoadsBefore + 1);
      expect(store.loadCalls, healthLoadsBefore + 1);
      expect(disconnectedTitle, findsOneWidget);
      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text(l10n.accountsDisconnected), findsOneWidget);
    });

    testWidgets('disconnected UI comes from the DB, not from the action result', (
      tester,
    ) async {
      final store = _HealthStore([_health('item-1')]);
      await pumpLifecycle(
        tester,
        store: store,
        disconnectItem: (_) async => const Success(null),
      );

      await chooseMenu(tester, l10n.accountsBankMenuDisconnect);
      await tester.tap(find.text(l10n.accountsDisconnectConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsDisconnected), findsOneWidget);
      expect(disconnectedTitle, findsNothing);
    });

    testWidgets('disconnect failure is not success and re-reads the DB', (
      tester,
    ) async {
      final store = _HealthStore([_health('item-1')]);
      await pumpLifecycle(
        tester,
        store: store,
        disconnectItem: (_) async => const Failure(UnknownFailure()),
      );
      final healthLoadsBefore = store.loadCalls;

      await chooseMenu(tester, l10n.accountsBankMenuDisconnect);
      await tester.tap(find.text(l10n.accountsDisconnectConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsDisconnectError), findsOneWidget);
      expect(find.text(l10n.accountsDisconnected), findsNothing);
      expect(store.loadCalls, healthLoadsBefore + 1);
      expect(disconnectedTitle, findsNothing);
    });

    testWidgets('disconnect double tap sends one request', (tester) async {
      final completer = Completer<Result<void>>();
      var calls = 0;
      await pumpLifecycle(
        tester,
        store: _HealthStore([_health('item-1')]),
        disconnectItem: (_) {
          calls += 1;
          return completer.future;
        },
      );

      await chooseMenu(tester, l10n.accountsBankMenuDisconnect);
      await tester.tap(find.text(l10n.accountsDisconnectConfirm));
      await tester.pump();

      expect(calls, 1);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const Success(null));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('delete active connection uses delete and the bank disappears', (
      tester,
    ) async {
      final store = _HealthStore([_health('item-1')]);
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking')],
        institutions: [_institution()],
      );
      final disconnectCalls = <String>[];
      final deleteCalls = <String>[];
      await pumpLifecycle(
        tester,
        store: store,
        repository: repository,
        disconnectItem: (id) async {
          disconnectCalls.add(id);
          return const Success(null);
        },
        deleteItem: (id) async {
          deleteCalls.add(id);
          repository.removeConnection(id);
          store.remove(id);
          return const Success(null);
        },
      );
      final accountLoadsBefore = repository.getAccountsCalls;

      await chooseMenu(tester, l10n.accountsBankMenuRemoveConnection);
      expect(
        find.text(l10n.accountsRemoveBankConnectionDialogBody),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.accountsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(deleteCalls, ['item-1']);
      expect(disconnectCalls, isEmpty);
      expect(repository.getAccountsCalls, accountLoadsBefore + 1);
      expect(find.text('Test Bank'), findsNothing);
      expect(find.byType(AccountsEmptyState), findsOneWidget);
      expect(find.text(l10n.accountsConnectionDeleted), findsOneWidget);
    });

    testWidgets('delete disconnected connection uses delete', (tester) async {
      final store = _HealthStore([
        _health('item-1', disconnectedAt: DateTime.utc(2026, 10, 3)),
      ]);
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking')],
        institutions: [_institution()],
      );
      final deleteCalls = <String>[];
      await pumpLifecycle(
        tester,
        store: store,
        repository: repository,
        deleteItem: (id) async {
          deleteCalls.add(id);
          repository.removeConnection(id);
          store.remove(id);
          return const Success(null);
        },
      );

      await chooseMenu(tester, l10n.accountsBankMenuRemoveConnection);
      await tester.tap(find.text(l10n.accountsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(deleteCalls, ['item-1']);
      expect(find.text('Test Bank'), findsNothing);
      expect(disconnectedTitle, findsNothing);
    });

    testWidgets('delete confirmation is separate and destructive', (
      tester,
    ) async {
      await pumpLifecycle(tester, store: _HealthStore([_health('item-1')]));

      await chooseMenu(tester, l10n.accountsBankMenuRemoveConnection);

      expect(
        find.text(l10n.accountsRemoveBankConnectionDialogTitle),
        findsOneWidget,
      );
      expect(find.text(l10n.accountsDisconnectDialogBody), findsNothing);
      final confirm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, l10n.accountsDeleteConfirm),
      );
      expect(
        confirm.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColors.error,
      );
    });

    testWidgets('delete cancel calls nothing', (tester) async {
      final calls = <String>[];
      await pumpLifecycle(
        tester,
        store: _HealthStore([_health('item-1')]),
        deleteItem: (id) async {
          calls.add(id);
          return const Success(null);
        },
      );

      await chooseMenu(tester, l10n.accountsBankMenuRemoveConnection);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(find.text('Test Bank'), findsOneWidget);
    });

    testWidgets('delete failure keeps the bank, shows error and re-reads', (
      tester,
    ) async {
      final store = _HealthStore([_health('item-1')]);
      await pumpLifecycle(
        tester,
        store: store,
        deleteItem: (_) async => const Failure(UnknownFailure()),
      );
      final healthLoadsBefore = store.loadCalls;

      await chooseMenu(tester, l10n.accountsBankMenuRemoveConnection);
      await tester.tap(find.text(l10n.accountsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text(l10n.accountsRemoveBankConnectionError), findsOneWidget);
      expect(find.text(l10n.accountsConnectionDeleted), findsNothing);
      expect(store.loadCalls, healthLoadsBefore + 1);
    });

    testWidgets('partial delete failure shows the DB state, not success', (
      tester,
    ) async {
      final store = _HealthStore([_health('item-1')]);
      await pumpLifecycle(
        tester,
        store: store,
        deleteItem: (id) async {
          // local_lifecycle_failed after the Disconnect half committed.
          store.disconnect(id);
          return const Failure(UnknownFailure());
        },
      );

      await chooseMenu(tester, l10n.accountsBankMenuRemoveConnection);
      await tester.tap(find.text(l10n.accountsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsRemoveBankConnectionError), findsOneWidget);
      expect(disconnectedTitle, findsOneWidget);
      expect(find.text('Test Bank'), findsOneWidget);
    });

    testWidgets('delete connection_not_found shows message and re-reads', (
      tester,
    ) async {
      final store = _HealthStore([_health('item-1')]);
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking')],
        institutions: [_institution()],
      );
      await pumpLifecycle(
        tester,
        store: store,
        repository: repository,
        deleteItem: (id) async {
          repository.removeConnection(id);
          store.remove(id);
          return const Failure(NotFoundFailure());
        },
      );

      await chooseMenu(tester, l10n.accountsBankMenuRemoveConnection);
      await tester.tap(find.text(l10n.accountsDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsConnectionNotFound), findsOneWidget);
      expect(find.text(l10n.accountsConnectionDeleted), findsNothing);
      expect(find.text('Test Bank'), findsNothing);
    });

    testWidgets('delete double tap sends one request', (tester) async {
      final completer = Completer<Result<void>>();
      var calls = 0;
      await pumpLifecycle(
        tester,
        store: _HealthStore([_health('item-1')]),
        deleteItem: (_) {
          calls += 1;
          return completer.future;
        },
      );

      await chooseMenu(tester, l10n.accountsBankMenuRemoveConnection);
      await tester.tap(find.text(l10n.accountsDeleteConfirm));
      await tester.pump();

      expect(calls, 1);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const Failure(UnknownFailure()));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('sync and lifecycle actions exclude each other', (
      tester,
    ) async {
      final syncGate = Completer<Result<PlaidAccountsSyncSummary>>();
      final disconnectGate = Completer<Result<void>>();
      var syncCalls = 0;
      var disconnectCalls = 0;
      await pumpLifecycle(
        tester,
        store: _HealthStore([_health('item-1')]),
        syncAccounts: (_) {
          syncCalls += 1;
          return syncGate.future;
        },
        disconnectItem: (_) {
          disconnectCalls += 1;
          return disconnectGate.future;
        },
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuSync));
      await tester.pump();

      expect(syncCalls, 1);
      expect(find.byIcon(Icons.more_vert), findsNothing);

      syncGate.complete(
        const Success(PlaidAccountsSyncSummary(syncedAccountCount: 1)),
      );
      await tester.pumpAndSettle();

      await chooseMenu(tester, l10n.accountsBankMenuDisconnect);
      await tester.tap(find.text(l10n.accountsDisconnectConfirm));
      await tester.pump();

      expect(disconnectCalls, 1);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(syncCalls, 1);

      disconnectGate.complete(const Success(null));
      await tester.pumpAndSettle();
    });
  });

  group('AccountsScreen connection health', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final reconnectTitle = find.text(l10n.accountsReconnectRequiredTitle);
    final reconnectCta = find.widgetWithText(
      TextButton,
      l10n.accountsReconnectAction,
    );
    final extensionBody = find.text(l10n.accountsAccessExtensionRequired);
    final extendCta = find.widgetWithText(
      TextButton,
      l10n.accountsExtendAccessAction,
    );

    List<Account> twoBanks() => [
      _account(name: 'Checking'),
      _account(
        id: 'account-2',
        name: 'Savings',
        institutionId: 'institution-2',
        plaidItemId: 'item-2',
        plaidAccountId: 'plaid-account-2',
      ),
    ];

    List<Institution> twoInstitutions() => [
      _institution(),
      _institution(id: 'institution-2', name: 'Second Bank'),
    ];

    FakePlaidFunctions repairBackend({
      FakeFunctionHandler? createLinkToken,
      FakeFunctionHandler? refresh,
    }) {
      return FakePlaidFunctions({
        'plaid-create-link-token':
            createLinkToken ??
            (_) => okResponse({
              'link_token': 'link-update-token',
              'expiration': '2026-10-03T14:00:00Z',
              'mode': 'update',
            }),
        'plaid-refresh-item-status':
            refresh ?? (_) => okResponse({'status': 'active'}),
      });
    }

    Future<void> pumpScreen(
      WidgetTester tester, {
      required _HealthStore store,
      _FakeAccountRepository? repository,
      FakePlaidFunctions? functions,
      FakePlaidLink? link,
      PlaidAccountsSyncCallback? syncAccounts,
    }) async {
      await tester.pumpWidget(
        _TestApp(
          repository:
              repository ??
              _FakeAccountRepository(
                accounts: twoBanks(),
                institutions: twoInstitutions(),
              ),
          healthStore: store,
          connectService: fakeConnectService(
            functions ?? repairBackend(),
            link ?? FakePlaidLink(),
          ),
          syncAccounts: syncAccounts ?? _successfulSync,
          child: const AccountsScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('login_required health warns only its own bank group', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', status: PlaidConnectionStatus.loginRequired),
          _health('item-2'),
        ]),
      );

      expect(
        find.byKey(const ValueKey('connection-health-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('connection-health-item-2')),
        findsNothing,
      );
      expect(reconnectTitle, findsOneWidget);
    });

    testWidgets('login_required warning is user-facing with Reconnect CTA', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', status: PlaidConnectionStatus.loginRequired),
        ]),
      );

      expect(reconnectTitle, findsOneWidget);
      expect(find.text(l10n.accountsReconnectRequiredBody), findsOneWidget);
      expect(reconnectCta, findsOneWidget);
      expect(find.textContaining('ITEM_LOGIN_REQUIRED'), findsNothing);
      expect(find.textContaining('login_required'), findsNothing);
    });

    testWidgets('healthy connection shows no warning', (tester) async {
      await pumpScreen(
        tester,
        store: _HealthStore([_health('item-1'), _health('item-2')]),
      );

      expect(reconnectTitle, findsNothing);
      expect(reconnectCta, findsNothing);
      expect(find.byKey(const ValueKey('connection-health-item-1')), findsNothing);
    });

    testWidgets('future consent expiry shows no warning', (tester) async {
      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', consentExpiresAt: DateTime.utc(2099, 12, 1)),
        ]),
      );

      expect(
        find.byKey(const ValueKey('connection-health-item-1')),
        findsNothing,
      );
      expect(extensionBody, findsNothing);
      expect(reconnectCta, findsNothing);
    });

    testWidgets('pending disconnect shows soft warning with Extend CTA', (
      tester,
    ) async {
      final link = FakePlaidLink();
      await pumpScreen(
        tester,
        store: _HealthStore([
          _health(
            'item-1',
            consentExpiresAt: DateTime.utc(2099, 12, 1),
            pendingDisconnectAt: DateTime.utc(2099, 11, 15),
          ),
          _health('item-2'),
        ]),
        link: link,
      );

      expect(
        find.byKey(const ValueKey('connection-health-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('connection-health-item-2')),
        findsNothing,
      );
      expect(extensionBody, findsOneWidget);
      expect(extendCta, findsOneWidget);
      expect(reconnectTitle, findsNothing);
      expect(reconnectCta, findsNothing);
      expect(find.textContaining('2099'), findsNothing);
      expect(link.openedTokens, isEmpty);
    });

    testWidgets('login_required takes priority over pending disconnect', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        store: _HealthStore([
          _health(
            'item-1',
            status: PlaidConnectionStatus.loginRequired,
            pendingDisconnectAt: DateTime.utc(2099, 11, 15),
          ),
        ]),
      );

      expect(reconnectTitle, findsOneWidget);
      expect(reconnectCta, findsOneWidget);
      expect(extensionBody, findsNothing);
      expect(extendCta, findsNothing);
    });

    testWidgets('reconnect_unavailable takes priority over pending disconnect', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', pendingDisconnectAt: DateTime.utc(2099, 11, 15)),
        ]),
        functions: repairBackend(
          createLinkToken: (_) => throw edgeError(409, 'reconnect_unavailable'),
        ),
      );

      await tester.tap(extendCta);
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsReconnectUnavailable), findsWidgets);
      expect(extensionBody, findsNothing);
      expect(extendCta, findsNothing);
    });

    testWidgets('extend access success syncs, refreshes and clears warning', (
      tester,
    ) async {
      final store = _HealthStore([
        _health('item-1', pendingDisconnectAt: DateTime.utc(2099, 11, 15)),
      ]);
      final functions = repairBackend(
        refresh: (body) {
          store.setStatus(
            body['connection_id'] as String,
            PlaidConnectionStatus.active,
          );
          return okResponse({'status': 'active', 'status_reason': null});
        },
      );
      final link = FakePlaidLink();
      final repository = _FakeAccountRepository(
        accounts: twoBanks(),
        institutions: twoInstitutions(),
      );
      final syncedConnectionIds = <String>[];

      await pumpScreen(
        tester,
        store: store,
        repository: repository,
        functions: functions,
        link: link,
        syncAccounts: (connectionId) async {
          syncedConnectionIds.add(connectionId);
          return const Success(PlaidAccountsSyncSummary(syncedAccountCount: 1));
        },
      );
      final accountLoadsBefore = repository.getAccountsCalls;
      final healthLoadsBefore = store.loadCalls;

      await tester.tap(extendCta);
      await tester.pumpAndSettle();

      expect(functions.calls.first.body['connection_id'], 'item-1');
      expect(link.openedTokens, ['link-update-token']);
      expect(functions.functionNames, [
        'plaid-create-link-token',
        'plaid-refresh-item-status',
      ]);
      expect(syncedConnectionIds, ['item-1']);
      expect(repository.getAccountsCalls, accountLoadsBefore + 1);
      expect(store.loadCalls, healthLoadsBefore + 1);
      expect(find.text(l10n.accountsAccessExtended), findsOneWidget);
      expect(find.text(l10n.accountsReconnectSuccess), findsNothing);
      expect(extensionBody, findsNothing);
      expect(extendCta, findsNothing);
    });

    testWidgets('extend access cancel keeps warning without sync or exchange', (
      tester,
    ) async {
      final functions = repairBackend();
      final syncedConnectionIds = <String>[];

      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', pendingDisconnectAt: DateTime.utc(2099, 11, 15)),
        ]),
        functions: functions,
        link: FakePlaidLink(result: const PlaidLinkSessionExited()),
        syncAccounts: (connectionId) async {
          syncedConnectionIds.add(connectionId);
          return const Success(PlaidAccountsSyncSummary(syncedAccountCount: 1));
        },
      );

      await tester.tap(extendCta);
      await tester.pumpAndSettle();

      expect(extensionBody, findsOneWidget);
      expect(extendCta, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(functions.functionNames, ['plaid-create-link-token']);
      expect(syncedConnectionIds, isEmpty);
    });

    testWidgets('extend access shows progress and ignores a second tap', (
      tester,
    ) async {
      final functions = repairBackend();
      final link = FakePlaidLink()
        ..pending = Completer<PlaidLinkSessionResult>();

      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', pendingDisconnectAt: DateTime.utc(2099, 11, 15)),
        ]),
        functions: functions,
        link: link,
      );

      await tester.tap(extendCta);
      await tester.pump();
      await tester.tap(find.text(l10n.accountsExtendingAccess));
      await tester.pump();

      expect(link.openedTokens, hasLength(1));
      expect(functions.functionNames, ['plaid-create-link-token']);

      link.pending!.complete(const PlaidLinkSessionExited());
      await tester.pumpAndSettle();
    });

    testWidgets('reconnect confirmed active removes warning after refresh', (
      tester,
    ) async {
      final store = _HealthStore([
        _health('item-1', status: PlaidConnectionStatus.loginRequired),
      ]);
      final functions = repairBackend(
        refresh: (body) {
          store.setStatus(
            body['connection_id'] as String,
            PlaidConnectionStatus.active,
          );
          return okResponse({'status': 'active', 'status_reason': null});
        },
      );
      final link = FakePlaidLink();
      final repository = _FakeAccountRepository(
        accounts: twoBanks(),
        institutions: twoInstitutions(),
      );
      final syncedConnectionIds = <String>[];

      await pumpScreen(
        tester,
        store: store,
        repository: repository,
        functions: functions,
        link: link,
        syncAccounts: (connectionId) async {
          syncedConnectionIds.add(connectionId);
          return const Success(PlaidAccountsSyncSummary(syncedAccountCount: 1));
        },
      );
      final accountLoadsBefore = repository.getAccountsCalls;

      await tester.tap(reconnectCta);
      await tester.pumpAndSettle();

      expect(functions.calls.first.body['connection_id'], 'item-1');
      expect(link.openedTokens, ['link-update-token']);
      expect(functions.functionNames, [
        'plaid-create-link-token',
        'plaid-refresh-item-status',
      ]);
      expect(syncedConnectionIds, ['item-1']);
      expect(reconnectTitle, findsNothing);
      expect(find.text(l10n.accountsReconnectSuccess), findsOneWidget);
      expect(find.text(l10n.accountsAccessExtended), findsNothing);
      expect(repository.getAccountsCalls, accountLoadsBefore + 1);
    });

    testWidgets('post-repair sync login_required keeps repair UI', (
      tester,
    ) async {
      final store = _HealthStore([
        _health('item-1', status: PlaidConnectionStatus.loginRequired),
      ]);
      final link = FakePlaidLink();

      await pumpScreen(
        tester,
        store: store,
        functions: repairBackend(
          refresh: (body) {
            store.setStatus(
              body['connection_id'] as String,
              PlaidConnectionStatus.active,
            );
            return okResponse({'status': 'active', 'status_reason': null});
          },
        ),
        link: link,
        syncAccounts: (connectionId) async {
          return const Failure(PlaidItemLoginRequiredFailure());
        },
      );

      await tester.tap(reconnectCta);
      await tester.pumpAndSettle();

      expect(reconnectCta, findsOneWidget);
      expect(find.text(l10n.accountsReconnectSuccess), findsNothing);
      expect(find.text(l10n.accountsReconnectRequiredTitle), findsWidgets);
      expect(link.openedTokens, hasLength(1));
    });

    testWidgets('double tap does not start a second reconnect flow', (
      tester,
    ) async {
      final functions = repairBackend();
      final link = FakePlaidLink()
        ..pending = Completer<PlaidLinkSessionResult>();

      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', status: PlaidConnectionStatus.loginRequired),
        ]),
        functions: functions,
        link: link,
      );

      await tester.tap(reconnectCta);
      await tester.pump();
      await tester.tap(find.text(l10n.accountsReconnecting));
      await tester.pump();

      expect(link.openedTokens, hasLength(1));
      expect(functions.functionNames, ['plaid-create-link-token']);

      link.pending!.complete(const PlaidLinkSessionExited());
      await tester.pumpAndSettle();
    });

    testWidgets('server still login_required keeps warning', (tester) async {
      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', status: PlaidConnectionStatus.loginRequired),
        ]),
        functions: repairBackend(
          refresh: (_) => okResponse({
            'status': 'login_required',
            'status_reason': 'login_required',
          }),
        ),
      );

      await tester.tap(reconnectCta);
      await tester.pumpAndSettle();

      expect(reconnectTitle, findsOneWidget);
      expect(find.text(l10n.accountsReconnectStillRequired), findsOneWidget);
    });

    testWidgets('refresh failure keeps warning and allows retry', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', status: PlaidConnectionStatus.loginRequired),
        ]),
        functions: repairBackend(
          refresh: (_) => throw edgeError(502, 'plaid_request_failed'),
        ),
      );

      await tester.tap(reconnectCta);
      await tester.pumpAndSettle();

      expect(reconnectTitle, findsOneWidget);
      expect(reconnectCta, findsOneWidget);
      expect(find.text(l10n.accountsReconnectFailed), findsOneWidget);
    });

    testWidgets('cancel keeps warning without error or exchange', (
      tester,
    ) async {
      final functions = repairBackend();

      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', status: PlaidConnectionStatus.loginRequired),
        ]),
        functions: functions,
        link: FakePlaidLink(result: const PlaidLinkSessionExited()),
      );

      await tester.tap(reconnectCta);
      await tester.pumpAndSettle();

      expect(reconnectTitle, findsOneWidget);
      expect(reconnectCta, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(functions.functionNames, ['plaid-create-link-token']);
    });

    testWidgets('sync item_login_required shows repair UI without opening Link', (
      tester,
    ) async {
      final link = FakePlaidLink();
      final store = _HealthStore([_health('item-1'), _health('item-2')]);

      await pumpScreen(
        tester,
        store: store,
        link: link,
        syncAccounts: (connectionId) async {
          return const Failure(PlaidItemLoginRequiredFailure());
        },
      );
      final healthLoadsBefore = store.loadCalls;

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuSync));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('connection-health-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('connection-health-item-2')),
        findsNothing,
      );
      expect(reconnectCta, findsOneWidget);
      expect(find.text(l10n.failureUnknown), findsNothing);
      expect(store.loadCalls, greaterThan(healthLoadsBefore));
      expect(link.openedTokens, isEmpty);
    });

    testWidgets('reconnect_unavailable shows message and stops offering retry', (
      tester,
    ) async {
      final functions = repairBackend(
        createLinkToken: (_) => throw edgeError(409, 'reconnect_unavailable'),
      );
      final link = FakePlaidLink();

      await pumpScreen(
        tester,
        store: _HealthStore([
          _health('item-1', status: PlaidConnectionStatus.loginRequired),
        ]),
        functions: functions,
        link: link,
      );

      await tester.tap(reconnectCta);
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsReconnectUnavailable), findsWidgets);
      expect(reconnectCta, findsNothing);
      expect(functions.functionNames, ['plaid-create-link-token']);
      expect(link.openedTokens, isEmpty);
    });

    testWidgets('connection_not_found shows message and refreshes state', (
      tester,
    ) async {
      final store = _HealthStore([
        _health('item-1', status: PlaidConnectionStatus.loginRequired),
      ]);
      final repository = _FakeAccountRepository(
        accounts: twoBanks(),
        institutions: twoInstitutions(),
      );

      await pumpScreen(
        tester,
        store: store,
        repository: repository,
        functions: repairBackend(
          createLinkToken: (_) => throw edgeError(404, 'connection_not_found'),
        ),
      );
      final accountLoadsBefore = repository.getAccountsCalls;
      final healthLoadsBefore = store.loadCalls;

      await tester.tap(reconnectCta);
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsConnectionNotFound), findsOneWidget);
      expect(repository.getAccountsCalls, greaterThan(accountLoadsBefore));
      expect(store.loadCalls, greaterThan(healthLoadsBefore));
      expect(tester.takeException(), isNull);
    });
  });

  group('AccountsScreen connect duplicate protection', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final connectButton = find.widgetWithText(
      FilledButton,
      l10n.accountsConnectBank,
    );
    final checking = LinkAccount(
      id: 'plaid-account-1',
      mask: '0000',
      name: 'Checking',
      type: 'depository',
      subtype: 'checking',
      verificationStatus: null,
    );
    final savings = LinkAccount(
      id: 'plaid-account-2',
      mask: '1111',
      name: 'Savings',
      type: 'depository',
      subtype: 'savings',
      verificationStatus: null,
    );

    FakePlaidFunctions backend(FakeFunctionHandler exchange) {
      return FakePlaidFunctions({
        'plaid-create-link-token': (_) =>
            okResponse({'link_token': 'link-initial-token'}),
        'plaid-exchange-public-token': exchange,
      });
    }

    List<Map<String, dynamic>> exchangeBodies(FakePlaidFunctions functions) {
      return [
        for (final call in functions.calls)
          if (call.functionName == 'plaid-exchange-public-token') call.body,
      ];
    }

    Future<List<String>> pumpConnect(
      WidgetTester tester, {
      required FakePlaidFunctions functions,
      FakePlaidLink? link,
      List<LinkAccount>? accounts,
    }) async {
      final syncedConnectionIds = <String>[];
      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(accounts: []),
          connectService: fakeConnectService(
            functions,
            link ??
                FakePlaidLink(
                  result: PlaidLinkSessionSucceeded(
                    linkSuccess(accounts: accounts ?? [checking]),
                  ),
                ),
          ),
          syncAccounts: (connectionId) async {
            syncedConnectionIds.add(connectionId);
            return const Success(
              PlaidAccountsSyncSummary(syncedAccountCount: 1),
            );
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      return syncedConnectionIds;
    }

    // The connect button spinner keeps animating while a review dialog is open,
    // so pumpAndSettle would never settle.
    Future<void> tapConnect(WidgetTester tester) async {
      await tester.tap(connectButton);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Map<String, dynamic> decisionBody(String status, List<String> decisions) {
      return {
        'status': status,
        'accounts': [
          for (var i = 0; i < decisions.length; i++)
            {'index': i, 'decision': decisions[i]},
        ],
      };
    }

    const storedChecking = <String, Object?>{
      'name': 'Checking',
      'subtype': 'checking',
      'mask': '1234',
    };

    Map<String, dynamic> ambiguousBody([
      List<List<Map<String, Object?>>> candidates = const [
        [storedChecking],
      ],
    ]) {
      return {
        'status': 'confirmation_required',
        'accounts': [
          for (var i = 0; i < candidates.length; i++)
            {'index': i, 'decision': 'ambiguous', 'candidates': candidates[i]},
        ],
      };
    }

    testWidgets('duplicate shows the already connected dialog', (tester) async {
      final functions = backend(
        (_) => okResponse(decisionBody('duplicate', ['duplicate'])),
      );
      final synced = await pumpConnect(tester, functions: functions);

      await tapConnect(tester);

      expect(
        find.text(l10n.accountsDuplicateConnectionDialogTitle),
        findsOneWidget,
      );
      expect(
        find.text('Checking \u2022\u2022\u2022\u20220000'),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.accountsDuplicateConnectionDialogAction));
      await tester.pumpAndSettle();

      expect(exchangeBodies(functions), hasLength(1));
      expect(synced, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('partial duplicate lists existing accounts and close stops', (
      tester,
    ) async {
      final link = FakePlaidLink(
        result: PlaidLinkSessionSucceeded(
          linkSuccess(accounts: [checking, savings]),
        ),
      );
      final functions = backend(
        (_) =>
            okResponse(decisionBody('partial_duplicate', ['duplicate', 'new'])),
      );
      final synced = await pumpConnect(
        tester,
        functions: functions,
        link: link,
      );

      await tapConnect(tester);

      expect(
        find.text(l10n.accountsPartialDuplicateDialogTitle),
        findsOneWidget,
      );
      expect(
        find.text('Checking \u2022\u2022\u2022\u20220000'),
        findsOneWidget,
      );
      expect(find.text('Savings \u2022\u2022\u2022\u20221111'), findsNothing);

      await tester.tap(find.text(l10n.accountsPartialDuplicateDialogClose));
      await tester.pumpAndSettle();

      expect(link.openedTokens, hasLength(1));
      expect(exchangeBodies(functions), hasLength(1));
      expect(synced, isEmpty);
      expect(connectButton, findsOneWidget);
    });

    testWidgets('partial duplicate choose again reopens Link once', (
      tester,
    ) async {
      final link = FakePlaidLink(
        result: PlaidLinkSessionSucceeded(
          linkSuccess(accounts: [checking, savings]),
        ),
      );
      var exchanges = 0;
      final functions = backend((_) {
        exchanges += 1;
        if (exchanges == 1) {
          return okResponse(
            decisionBody('partial_duplicate', ['disconnected_existing', 'new']),
          );
        }
        return okResponse({'connection_id': 'item-new'});
      });
      final synced = await pumpConnect(
        tester,
        functions: functions,
        link: link,
      );

      await tapConnect(tester);
      expect(
        find.text(
          'Checking \u2022\u2022\u2022\u20220000 \u2014 '
          '${l10n.accountsLinkAccountDisconnectedLabel}',
        ),
        findsOneWidget,
      );

      link.result = PlaidLinkSessionSucceeded(linkSuccess(accounts: [savings]));
      await tester.tap(
        find.text(l10n.accountsPartialDuplicateDialogSelectAgain),
      );
      await tester.pumpAndSettle();

      expect(link.openedTokens, hasLength(2));
      expect(exchangeBodies(functions), hasLength(2));
      final second = exchangeBodies(functions).last;
      expect(
        (second['selected_accounts'] as List).map((a) => (a as Map)['name']),
        ['Savings'],
      );
      expect(synced, ['item-new']);
    });

    testWidgets('ambiguous dialog shows the similar account already in Ophir', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final functions = backend((_) => okResponse(ambiguousBody()));
      await pumpConnect(tester, functions: functions);

      await tapConnect(tester);

      for (final text in [
        l10n.accountsAmbiguousConnectionDialogTitle,
        l10n.accountsAmbiguousConnectionDialogBody(1),
        l10n.accountsAmbiguousConnectionDialogConnectingLabel,
        'Checking \u2022\u2022\u2022\u20220000',
        l10n.accountsAmbiguousConnectionDialogExistingLabel,
        'Checking',
        'checking \u2022 \u2022\u2022\u2022\u20221234',
        l10n.accountsAmbiguousConnectionDialogCheckDigitsQuestion(1),
        l10n.accountsAmbiguousConnectionDialogAlreadyConnected,
        l10n.accountsAmbiguousConnectionDialogConfirm,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byType(TextButton), findsNWidgets(2));
      final digits = tester.widget<Text>(
        find.text('checking \u2022 \u2022\u2022\u2022\u20221234'),
      );
      expect(digits.maxLines, isNull);
      expect(digits.overflow, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('similar account without a mask shows no placeholder digits', (
      tester,
    ) async {
      final functions = backend(
        (_) => okResponse(
          ambiguousBody([
            [
              {'name': 'Checking', 'subtype': null, 'mask': null},
            ],
          ]),
        ),
      );
      final noMask = LinkAccount(
        id: 'plaid-account-1',
        mask: null,
        name: 'Checking',
        type: 'depository',
        subtype: 'checking',
        verificationStatus: null,
      );
      await pumpConnect(tester, functions: functions, accounts: [noMask]);

      await tapConnect(tester);

      expect(find.text('Checking'), findsNWidgets(2));
      expect(find.textContaining('\u2022'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      expect(
        find.text(l10n.accountsAmbiguousConnectionDialogQuestion(1)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.accountsAmbiguousConnectionDialogCheckDigitsQuestion(1)),
        findsNothing,
      );
    });

    for (final (label, incomingMask, storedMask) in [
      ('selected account', null, '5678'),
      ('similar account', '1234', null),
    ]) {
      testWidgets('without a mask on the $label the question skips digits', (
        tester,
      ) async {
        final functions = backend(
          (_) => okResponse(
            ambiguousBody([
              [
                {'name': 'Checking', 'subtype': 'checking', 'mask': storedMask},
              ],
            ]),
          ),
        );
        final selected = LinkAccount(
          id: 'plaid-account-1',
          mask: incomingMask,
          name: 'Checking',
          type: 'depository',
          subtype: 'checking',
          verificationStatus: null,
        );
        final synced = await pumpConnect(
          tester,
          functions: functions,
          accounts: [selected],
        );

        await tapConnect(tester);

        expect(
          find.text(l10n.accountsAmbiguousConnectionDialogTitle),
          findsOneWidget,
        );
        if (incomingMask == null) {
          expect(find.text('Checking'), findsNWidgets(2));
        } else {
          expect(
            find.text('Checking \u2022\u2022\u2022\u2022$incomingMask'),
            findsOneWidget,
          );
        }
        expect(
          find.text(
            storedMask == null
                ? 'checking'
                : 'checking \u2022 \u2022\u2022\u2022\u2022$storedMask',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('null'), findsNothing);
        expect(
          find.text(l10n.accountsAmbiguousConnectionDialogQuestion(1)),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.accountsAmbiguousConnectionDialogCheckDigitsQuestion(1),
          ),
          findsNothing,
        );
        expect(exchangeBodies(functions), hasLength(1));
        expect(exchangeBodies(functions).single['confirm_ambiguous'], isFalse);
        expect(synced, isEmpty);
      });
    }

    testWidgets('several similar accounts are listed without picking one', (
      tester,
    ) async {
      final functions = backend(
        (_) => okResponse(
          ambiguousBody([
            [
              for (final mask in ['1111', '2222', '3333', '4444'])
                {'name': 'Checking', 'subtype': 'checking', 'mask': mask},
            ],
          ]),
        ),
      );
      await pumpConnect(tester, functions: functions);

      await tapConnect(tester);

      expect(
        find.text(l10n.accountsAmbiguousConnectionDialogBody(4)),
        findsOneWidget,
      );
      for (final mask in ['1111', '2222', '3333']) {
        expect(
          find.text('checking \u2022 \u2022\u2022\u2022\u2022$mask'),
          findsOneWidget,
        );
      }
      expect(find.textContaining('4444'), findsNothing);
      expect(
        find.text(l10n.accountsAmbiguousConnectionDialogMoreCandidates(1)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.accountsAmbiguousConnectionDialogCheckDigitsQuestion(4)),
        findsOneWidget,
      );
    });

    testWidgets('each selected account is shown with its own similar account', (
      tester,
    ) async {
      final functions = backend(
        (_) => okResponse(
          ambiguousBody([
            [storedChecking],
            [
              {'name': 'Savings', 'subtype': 'savings', 'mask': '5678'},
            ],
          ]),
        ),
      );
      await pumpConnect(
        tester,
        functions: functions,
        accounts: [checking, savings],
      );

      await tapConnect(tester);

      expect(
        find.text(l10n.accountsAmbiguousConnectionDialogConnectingLabel),
        findsNWidgets(2),
      );
      final checkingTop = tester.getTopLeft(
        find.text('Checking \u2022\u2022\u2022\u20220000'),
      );
      final storedCheckingTop = tester.getTopLeft(
        find.text('checking \u2022 \u2022\u2022\u2022\u20221234'),
      );
      final savingsTop = tester.getTopLeft(
        find.text('Savings \u2022\u2022\u2022\u20221111'),
      );
      final storedSavingsTop = tester.getTopLeft(
        find.text('savings \u2022 \u2022\u2022\u2022\u20225678'),
      );
      expect(checkingTop.dy, lessThan(storedCheckingTop.dy));
      expect(storedCheckingTop.dy, lessThan(savingsTop.dy));
      expect(savingsTop.dy, lessThan(storedSavingsTop.dy));
    });

    testWidgets('different account resends once with confirm_ambiguous', (
      tester,
    ) async {
      final functions = backend((body) {
        if (body['confirm_ambiguous'] == true) {
          return okResponse({'connection_id': 'item-new'});
        }
        return okResponse(ambiguousBody());
      });
      final link = FakePlaidLink(
        result: PlaidLinkSessionSucceeded(linkSuccess(accounts: [checking])),
      );
      final synced = await pumpConnect(
        tester,
        functions: functions,
        link: link,
      );

      await tapConnect(tester);
      await tester.tap(
        find.text(l10n.accountsAmbiguousConnectionDialogConfirm),
      );
      await tester.pumpAndSettle();

      final bodies = exchangeBodies(functions);
      expect(bodies.map((b) => b['confirm_ambiguous']), [false, true]);
      expect(bodies.last['public_token'], bodies.first['public_token']);
      expect(link.openedTokens, hasLength(1));
      expect(synced, ['item-new']);
    });

    final closeWithoutConnecting = <String, Future<void> Function(WidgetTester)>{
      'already connected': (tester) => tester.tap(
        find.text(l10n.accountsAmbiguousConnectionDialogAlreadyConnected),
      ),
      'tap outside': (tester) => tester.tapAt(const Offset(4, 4)),
      'back': (tester) => tester.binding.handlePopRoute(),
    };
    for (final MapEntry(key: label, value: close)
        in closeWithoutConnecting.entries) {
      testWidgets('$label closes the flow without connecting', (tester) async {
        final functions = backend((_) => okResponse(ambiguousBody()));
        final link = FakePlaidLink(
          result: PlaidLinkSessionSucceeded(linkSuccess(accounts: [checking])),
        );
        final synced = await pumpConnect(
          tester,
          functions: functions,
          link: link,
        );

        await tapConnect(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        await close(tester);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(exchangeBodies(functions), hasLength(1));
        expect(exchangeBodies(functions).single['confirm_ambiguous'], isFalse);
        expect(link.openedTokens, hasLength(1));
        expect(synced, isEmpty);
        expect(find.byType(SnackBar), findsNothing);
        expect(connectButton, findsOneWidget);
      });
    }

    for (final (status, title) in [
      ('duplicate', l10n.accountsDuplicateConnectionDialogTitle),
      (
        'disconnected_existing',
        l10n.accountsDisconnectedExistingDialogTitle,
      ),
    ]) {
      testWidgets('different account rechecked as $status is blocked', (
        tester,
      ) async {
        final functions = backend((body) {
          if (body['confirm_ambiguous'] == true) {
            return okResponse(decisionBody(status, [status]));
          }
          return okResponse(ambiguousBody());
        });
        final link = FakePlaidLink(
          result: PlaidLinkSessionSucceeded(linkSuccess(accounts: [checking])),
        );
        final synced = await pumpConnect(
          tester,
          functions: functions,
          link: link,
        );

        await tapConnect(tester);
        await tester.tap(
          find.text(l10n.accountsAmbiguousConnectionDialogConfirm),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(title), findsOneWidget);
        expect(
          find.text(l10n.accountsAmbiguousConnectionDialogConfirm),
          findsNothing,
        );
        expect(exchangeBodies(functions), hasLength(2));
        expect(link.openedTokens, hasLength(1));
        expect(synced, isEmpty);
      });
    }

    testWidgets('disconnected existing explains that deletion comes first', (
      tester,
    ) async {
      final functions = backend(
        (_) => okResponse(
          decisionBody('disconnected_existing', ['disconnected_existing']),
        ),
      );
      final synced = await pumpConnect(tester, functions: functions);

      await tapConnect(tester);

      expect(
        find.text(l10n.accountsDisconnectedExistingDialogTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.accountsDisconnectedExistingDialogBody),
        findsOneWidget,
      );
      await tester.tap(
        find.text(l10n.accountsDisconnectedExistingDialogAction),
      );
      await tester.pumpAndSettle();

      expect(exchangeBodies(functions), hasLength(1));
      expect(synced, isEmpty);
    });

    testWidgets('null mask new account connects instead of cancelling', (
      tester,
    ) async {
      final functions = backend(
        (_) => okResponse({'connection_id': 'item-new'}),
      );
      final link = FakePlaidLink(
        result: PlaidLinkSessionSucceeded(
          linkSuccess(
            accounts: [
              LinkAccount(
                id: 'plaid-account-1',
                mask: null,
                name: 'Checking',
                type: 'depository',
                subtype: 'checking',
                verificationStatus: null,
              ),
            ],
          ),
        ),
      );
      final synced = await pumpConnect(
        tester,
        functions: functions,
        link: link,
      );

      await tapConnect(tester);

      expect(synced, ['item-new']);
      final sent = exchangeBodies(functions).single;
      expect(
        ((sent['selected_accounts'] as List).single as Map)['mask'],
        isNull,
      );
    });

    testWidgets('system failure shows the generic error, not a duplicate', (
      tester,
    ) async {
      final functions = backend(
        (_) => throw edgeError(500, 'duplicate_check_failed'),
      );
      final synced = await pumpConnect(tester, functions: functions);

      await tapConnect(tester);

      expect(find.text(l10n.failureUnknown), findsOneWidget);
      expect(
        find.text(l10n.accountsDuplicateConnectionDialogTitle),
        findsNothing,
      );
      expect(synced, isEmpty);
    });

    testWidgets('unknown server status fails closed with the generic error', (
      tester,
    ) async {
      final functions = backend((_) => okResponse({'status': 'merged'}));
      final synced = await pumpConnect(tester, functions: functions);

      await tapConnect(tester);

      expect(find.text(l10n.failureUnknown), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(synced, isEmpty);
    });

    testWidgets('double tap on connect opens Link only once', (tester) async {
      final functions = backend(
        (_) => okResponse({'connection_id': 'item-new'}),
      );
      final link = FakePlaidLink()
        ..pending = Completer<PlaidLinkSessionResult>();
      await pumpConnect(tester, functions: functions, link: link);

      await tester.tap(connectButton);
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(link.openedTokens, hasLength(1));
      expect(
        functions.functionNames.where((n) => n == 'plaid-create-link-token'),
        hasLength(1),
      );

      link.pending!.complete(const PlaidLinkSessionExited());
      await tester.pumpAndSettle();
      expect(exchangeBodies(functions), isEmpty);
    });
  });
}

final class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.repository,
    required this.child,
    this.syncAccounts,
    this.disconnectItem,
    this.deleteItem,
    this.healthStore,
    this.connectService,
  });

  final AccountRepository repository;
  final Widget child;
  final PlaidAccountsSyncCallback? syncAccounts;
  final PlaidItemLifecycleCallback? disconnectItem;
  final PlaidItemLifecycleCallback? deleteItem;
  final _HealthStore? healthStore;
  final PlaidConnectService? connectService;

  @override
  Widget build(BuildContext context) {
    final store = healthStore ?? _HealthStore();
    return ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(repository),
        plaidConnectionHealthLoaderProvider.overrideWithValue(store.load),
        plaidConnectServiceProvider.overrideWithValue(
          connectService ??
              fakeConnectService(FakePlaidFunctions({}), FakePlaidLink()),
        ),
        if (syncAccounts != null)
          plaidAccountsSyncCallbackProvider.overrideWithValue(syncAccounts!),
        if (disconnectItem != null)
          plaidItemDisconnectCallbackProvider.overrideWithValue(
            disconnectItem!,
          ),
        if (deleteItem != null)
          plaidItemDeleteCallbackProvider.overrideWithValue(deleteItem!),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }
}

Future<Result<PlaidAccountsSyncSummary>> _successfulSync(
  String connectionId,
) async {
  return const Success(PlaidAccountsSyncSummary(syncedAccountCount: 1));
}

final class _HealthStore {
  _HealthStore([List<PlaidConnectionHealth>? health])
    : health = health ?? <PlaidConnectionHealth>[];

  List<PlaidConnectionHealth> health;
  int loadCalls = 0;

  Future<Result<List<PlaidConnectionHealth>>> load() async {
    loadCalls += 1;
    return Success(List.of(health));
  }

  void setStatus(String connectionId, PlaidConnectionStatus status) {
    health = [
      for (final item in health)
        if (item.connectionId == connectionId)
          _health(connectionId, status: status)
        else
          item,
    ];
  }

  /// What the server-side Disconnect leaves behind: health fields untouched,
  /// disconnected_at set.
  void disconnect(String connectionId) {
    health = [
      for (final item in health)
        if (item.connectionId == connectionId)
          PlaidConnectionHealth(
            connectionId: item.connectionId,
            status: item.status,
            statusReason: item.statusReason,
            pendingDisconnectAt: item.pendingDisconnectAt,
            disconnectedAt: DateTime.utc(2026, 10, 3),
          )
        else
          item,
    ];
  }

  void remove(String connectionId) {
    health = [
      for (final item in health)
        if (item.connectionId != connectionId) item,
    ];
  }
}

PlaidConnectionHealth _health(
  String connectionId, {
  PlaidConnectionStatus status = PlaidConnectionStatus.active,
  DateTime? consentExpiresAt,
  DateTime? pendingDisconnectAt,
  DateTime? disconnectedAt,
}) {
  return PlaidConnectionHealth(
    connectionId: connectionId,
    status: status,
    statusReason: status == PlaidConnectionStatus.loginRequired
        ? PlaidConnectionStatusReason.loginRequired
        : null,
    consentExpiresAt: consentExpiresAt,
    pendingDisconnectAt: pendingDisconnectAt,
    disconnectedAt: disconnectedAt,
  );
}

final class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({
    required this.accounts,
    this.institutions = const <Institution>[],
  });

  final List<Account> accounts;
  final List<Institution> institutions;
  final List<_ParticipationUpdate> participationUpdates =
      <_ParticipationUpdate>[];
  int getAccountsCalls = 0;

  @override
  Future<Result<List<Account>>> getAccounts() async {
    getAccountsCalls += 1;
    return Success(accounts);
  }

  @override
  Future<Result<List<Account>>> getFinanciallyActiveAccounts() async {
    return Success(
      accounts
          .where((account) => account.isIncludedInFinances)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<List<Institution>>> getInstitutions() async {
    return Success(institutions);
  }

  @override
  Future<Result<Account>> updateAccountFinancialParticipation({
    required String accountId,
    required bool isIncludedInFinances,
  }) async {
    participationUpdates.add(
      _ParticipationUpdate(accountId, isIncludedInFinances),
    );

    final index = accounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      return Success(
        _account(
          id: accountId,
          name: 'Missing',
          isIncludedInFinances: isIncludedInFinances,
        ),
      );
    }

    final updated = _copyAccount(
      accounts[index],
      isIncludedInFinances: isIncludedInFinances,
    );
    accounts[index] = updated;

    return Success(updated);
  }

  void removeConnection(String connectionId) {
    accounts.removeWhere((account) => account.plaidItemId == connectionId);
  }
}

final class _ParticipationUpdate {
  const _ParticipationUpdate(this.accountId, this.isIncludedInFinances);

  final String accountId;
  final bool isIncludedInFinances;

  @override
  bool operator ==(Object other) {
    return other is _ParticipationUpdate &&
        other.accountId == accountId &&
        other.isIncludedInFinances == isIncludedInFinances;
  }

  @override
  int get hashCode => Object.hash(accountId, isIncludedInFinances);

  @override
  String toString() {
    return '_ParticipationUpdate($accountId, $isIncludedInFinances)';
  }
}

Account _account({
  String id = 'account-1',
  required String name,
  String institutionId = 'institution-1',
  String plaidItemId = 'item-1',
  String plaidAccountId = 'plaid-account-1',
  bool isIncludedInFinances = true,
}) {
  final now = DateTime(2026, 7, 23);

  return Account(
    id: id,
    userId: 'user-1',
    name: name,
    type: AccountType.bank,
    currencyCode: 'CAD',
    institutionId: institutionId,
    plaidItemId: plaidItemId,
    plaidAccountId: plaidAccountId,
    mask: '1234',
    currentBalance: 100,
    iconKey: 'bank',
    colorKey: 'blue',
    sortOrder: 0,
    isArchived: false,
    isIncludedInFinances: isIncludedInFinances,
    createdAt: now,
    updatedAt: now,
  );
}

Account _copyAccount(Account account, {required bool isIncludedInFinances}) {
  return Account(
    id: account.id,
    userId: account.userId,
    name: account.name,
    type: account.type,
    currencyCode: account.currencyCode,
    unofficialCurrencyCode: account.unofficialCurrencyCode,
    initialBalance: account.initialBalance,
    iconKey: account.iconKey,
    colorKey: account.colorKey,
    sortOrder: account.sortOrder,
    isArchived: account.isArchived,
    isIncludedInFinances: isIncludedInFinances,
    createdAt: account.createdAt,
    updatedAt: account.updatedAt,
    plaidItemId: account.plaidItemId,
    institutionId: account.institutionId,
    plaidAccountId: account.plaidAccountId,
    officialName: account.officialName,
    mask: account.mask,
    plaidType: account.plaidType,
    plaidSubtype: account.plaidSubtype,
    currentBalance: account.currentBalance,
    availableBalance: account.availableBalance,
    balanceFetchedAt: account.balanceFetchedAt,
  );
}

Institution _institution({
  String id = 'institution-1',
  String name = 'Test Bank',
}) {
  final now = DateTime(2026, 7, 23);

  return Institution(
    id: id,
    userId: 'user-1',
    plaidItemId: id == 'institution-1' ? 'item-1' : 'item-2',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

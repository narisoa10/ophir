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

    testWidgets('bank menu shows sync and destructive remove', (tester) async {
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

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountsBankMenuSync), findsOneWidget);
      expect(find.text(l10n.accountsBankMenuRemoveConnection), findsOneWidget);

      final removeText = tester.widget<Text>(
        find.text(l10n.accountsBankMenuRemoveConnection),
      );
      expect(removeText.style?.color, AppColors.error);
    });

    testWidgets('remove cancel does not call backend', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final removedConnectionIds = <String>[];

      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          removeItem: (connectionId) async {
            removedConnectionIds.add(connectionId);
            return const Success(null);
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuRemoveConnection));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(removedConnectionIds, isEmpty);
      expect(find.text('Test Bank'), findsOneWidget);
    });

    testWidgets('remove confirm calls backend once', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final removedConnectionIds = <String>[];

      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          removeItem: (connectionId) async {
            removedConnectionIds.add(connectionId);
            return const Success(null);
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuRemoveConnection));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(removedConnectionIds, ['item-1']);
    });

    testWidgets('successful remove refreshes accounts and bank disappears', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final repository = _FakeAccountRepository(
        accounts: [_account(name: 'Checking')],
        institutions: [_institution()],
      );

      await tester.pumpWidget(
        _TestApp(
          repository: repository,
          removeItem: (connectionId) async {
            repository.removeConnection(connectionId);
            return const Success(null);
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      expect(repository.getAccountsCalls, 1);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuRemoveConnection));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(repository.getAccountsCalls, greaterThan(1));
      expect(find.text('Test Bank'), findsNothing);
      expect(find.byType(AccountsEmptyState), findsOneWidget);
    });

    testWidgets('remove error leaves bank visible and shows feedback', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          removeItem: (connectionId) async {
            return const Failure(UnknownFailure());
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuRemoveConnection));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(find.text('Test Bank'), findsOneWidget);
      expect(find.text(l10n.accountsRemoveBankConnectionError), findsOneWidget);
    });

    testWidgets('remove double submit is prevented', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final completer = Completer<Result<void>>();
      var removeCallCount = 0;

      await tester.pumpWidget(
        _TestApp(
          repository: _FakeAccountRepository(
            accounts: [_account(name: 'Checking')],
            institutions: [_institution()],
          ),
          removeItem: (connectionId) {
            removeCallCount += 1;
            return completer.future;
          },
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountsBankMenuRemoveConnection));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pump();

      expect(removeCallCount, 1);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const Success(null));
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
}

final class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.repository,
    required this.child,
    this.syncAccounts,
    this.removeItem,
    this.healthStore,
    this.connectService,
  });

  final AccountRepository repository;
  final Widget child;
  final PlaidAccountsSyncCallback? syncAccounts;
  final PlaidItemRemoveCallback? removeItem;
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
        if (removeItem != null)
          plaidItemRemoveCallbackProvider.overrideWithValue(removeItem!),
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
}

PlaidConnectionHealth _health(
  String connectionId, {
  PlaidConnectionStatus status = PlaidConnectionStatus.active,
  DateTime? consentExpiresAt,
  DateTime? pendingDisconnectAt,
}) {
  return PlaidConnectionHealth(
    connectionId: connectionId,
    status: status,
    statusReason: status == PlaidConnectionStatus.loginRequired
        ? PlaidConnectionStatusReason.loginRequired
        : null,
    consentExpiresAt: consentExpiresAt,
    pendingDisconnectAt: pendingDisconnectAt,
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

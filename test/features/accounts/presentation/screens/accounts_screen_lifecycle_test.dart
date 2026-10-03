import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/accounts/controller/account_providers.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_accounts_sync_service.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_connect_service.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/entities/institution.dart';
import 'package:ophir/features/accounts/domain/entities/plaid_connection_health.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/accounts/domain/repositories/account_repository.dart';
import 'package:ophir/features/accounts/presentation/screens/accounts_screen.dart';

import '../../support/plaid_test_fakes.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final reconnectTitle = find.text(l10n.accountsReconnectRequiredTitle);
  final reconnectCta = find.widgetWithText(
    TextButton,
    l10n.accountsReconnectAction,
  );

  late _FakeAccountRepository repository;
  late _FakeHealthLoader health;
  late FakePlaidFunctions functions;
  late FakePlaidLink link;
  late List<String> syncCalls;

  setUp(() {
    repository = _FakeAccountRepository(balance: 100);
    health = _FakeHealthLoader(PlaidConnectionStatus.active);
    functions = FakePlaidFunctions({
      'plaid-create-link-token': (body) => okResponse({
        'link_token': 'link-token',
        'expiration': '2026-10-03T14:00:00Z',
        if (body.containsKey('connection_id')) 'mode': 'update',
      }),
      'plaid-refresh-item-status': (body) {
        health
          ..status = PlaidConnectionStatus.active
          ..pendingDisconnectAt = null;
        return okResponse({'status': 'active', 'status_reason': null});
      },
    });
    link = FakePlaidLink();
    syncCalls = <String>[];
  });

  Future<void> pumpApp(WidgetTester tester) async {
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repository),
          plaidConnectionHealthLoaderProvider.overrideWithValue(health.load),
          plaidConnectServiceProvider.overrideWithValue(
            fakeConnectService(functions, link),
          ),
          plaidAccountsSyncCallbackProvider.overrideWithValue((id) async {
            syncCalls.add(id);
            return const Success(PlaidAccountsSyncSummary(syncedAccountCount: 0));
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _Launcher(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAccounts(WidgetTester tester) async {
    await tester.tap(find.text('open accounts'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountsScreen), findsOneWidget);
  }

  Future<void> leaveAccounts(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(AccountsScreen), findsNothing);
  }

  void sendToBackground(WidgetTester tester) {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void bringToForeground(WidgetTester tester) {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  Future<void> backgroundAndResume(WidgetTester tester) async {
    sendToBackground(tester);
    await tester.pump();
    bringToForeground(tester);
    await tester.pump();
  }

  ({int accounts, int institutions, int health}) reads() => (
    accounts: repository.getAccountsCalls,
    institutions: repository.getInstitutionsCalls,
    health: health.loadCalls,
  );

  void expectNoPlaidSideEffects() {
    expect(functions.calls, isEmpty);
    expect(link.openedTokens, isEmpty);
    expect(syncCalls, isEmpty);
  }

  group('AccountsScreen entry and resume refresh', () {
    testWidgets('first load reads each source once', (tester) async {
      await pumpApp(tester);
      await openAccounts(tester);

      expect(reads(), (accounts: 1, institutions: 1, health: 1));
      expect(find.text('100.00 CAD'), findsOneWidget);
      expectNoPlaidSideEffects();
    });

    testWidgets('re-entry shows the new DB snapshot without Sync', (
      tester,
    ) async {
      await pumpApp(tester);
      await openAccounts(tester);
      await leaveAccounts(tester);

      repository.balance = 250;
      health.status = PlaidConnectionStatus.loginRequired;

      await openAccounts(tester);

      expect(find.text('250.00 CAD'), findsOneWidget);
      expect(find.text('100.00 CAD'), findsNothing);
      expect(reconnectTitle, findsOneWidget);
      expect(reads(), (accounts: 2, institutions: 2, health: 2));
      expectNoPlaidSideEffects();
    });

    testWidgets('resume refreshes balance and health while open', (
      tester,
    ) async {
      await pumpApp(tester);
      await openAccounts(tester);

      repository.balance = 250;
      health.status = PlaidConnectionStatus.loginRequired;

      await backgroundAndResume(tester);
      await tester.pumpAndSettle();

      expect(find.text('250.00 CAD'), findsOneWidget);
      expect(reconnectTitle, findsOneWidget);
      expect(reads(), (accounts: 2, institutions: 2, health: 2));
      expectNoPlaidSideEffects();
    });

    testWidgets('resume during an in-flight refresh joins it', (tester) async {
      await pumpApp(tester);
      await openAccounts(tester);

      final gate = Completer<void>();
      repository.gate = gate;

      await backgroundAndResume(tester);
      await backgroundAndResume(tester);

      gate.complete();
      await tester.pumpAndSettle();

      expect(reads(), (accounts: 2, institutions: 2, health: 2));
    });

    testWidgets('resume while initial connect Link is open is ignored', (
      tester,
    ) async {
      link.pending = Completer<PlaidLinkSessionResult>();
      await pumpApp(tester);
      await openAccounts(tester);
      final before = reads();

      await tester.tap(find.text(l10n.accountsConnectBank));
      await tester.pump();
      expect(link.openedTokens, ['link-token']);

      await backgroundAndResume(tester);
      expect(reads(), before);

      link.pending!.complete(const PlaidLinkSessionExited());
      await tester.pumpAndSettle();

      expect(reads(), before);
      expect(functions.functionNames, ['plaid-create-link-token']);
      expect(find.text(l10n.accountsConnectBank), findsOneWidget);
    });

    testWidgets('resume then cancel during reconnect keeps warning', (
      tester,
    ) async {
      health.status = PlaidConnectionStatus.loginRequired;
      link.pending = Completer<PlaidLinkSessionResult>();
      await pumpApp(tester);
      await openAccounts(tester);
      final before = reads();

      await tester.tap(reconnectCta);
      await tester.pump();
      expect(link.openedTokens, ['link-token']);

      await backgroundAndResume(tester);
      expect(reads(), before);

      link.pending!.complete(const PlaidLinkSessionExited());
      await tester.pumpAndSettle();

      expect(reads(), before);
      expect(functions.functionNames, ['plaid-create-link-token']);
      expect(reconnectTitle, findsOneWidget);
      expect(reconnectCta, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('resume during reconnect success adds no competing refresh', (
      tester,
    ) async {
      health.status = PlaidConnectionStatus.loginRequired;
      link.pending = Completer<PlaidLinkSessionResult>();
      await pumpApp(tester);
      await openAccounts(tester);
      final before = reads();

      await tester.tap(reconnectCta);
      await tester.pump();

      await backgroundAndResume(tester);
      expect(reads(), before);

      link.pending!.complete(PlaidLinkSessionSucceeded(linkSuccess()));
      await tester.pumpAndSettle();

      expect(functions.functionNames, [
        'plaid-create-link-token',
        'plaid-refresh-item-status',
      ]);
      expect(syncCalls, ['item-1']);
      expect(reconnectTitle, findsNothing);
      expect(find.text(l10n.accountsReconnectSuccess), findsOneWidget);
      expect(reads(), (
        accounts: before.accounts + 1,
        institutions: before.institutions + 1,
        health: before.health + 1,
      ));
    });

    testWidgets('resume during extend access success adds no competing refresh', (
      tester,
    ) async {
      health.pendingDisconnectAt = DateTime.utc(2099, 11, 15);
      link.pending = Completer<PlaidLinkSessionResult>();
      await pumpApp(tester);
      await openAccounts(tester);
      final before = reads();
      final extendCta = find.widgetWithText(
        TextButton,
        l10n.accountsExtendAccessAction,
      );

      await tester.tap(extendCta);
      await tester.pump();

      await backgroundAndResume(tester);
      expect(reads(), before);

      link.pending!.complete(PlaidLinkSessionSucceeded(linkSuccess()));
      await tester.pumpAndSettle();

      expect(functions.functionNames, [
        'plaid-create-link-token',
        'plaid-refresh-item-status',
      ]);
      expect(syncCalls, ['item-1']);
      expect(extendCta, findsNothing);
      expect(find.text(l10n.accountsAccessExtended), findsOneWidget);
      expect(reads(), (
        accounts: before.accounts + 1,
        institutions: before.institutions + 1,
        health: before.health + 1,
      ));
    });

    testWidgets('failed resume refresh keeps last-good data silently', (
      tester,
    ) async {
      await pumpApp(tester);
      await openAccounts(tester);

      repository.fail = true;
      health.fail = true;

      await backgroundAndResume(tester);
      await tester.pumpAndSettle();

      expect(reads(), (accounts: 2, institutions: 2, health: 2));
      expect(find.text('100.00 CAD'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(reconnectTitle, findsNothing);
      expectNoPlaidSideEffects();
    });

    testWidgets('resume after leaving the screen does not refresh', (
      tester,
    ) async {
      await pumpApp(tester);
      await openAccounts(tester);
      await leaveAccounts(tester);

      await backgroundAndResume(tester);
      await tester.pumpAndSettle();

      expect(reads(), (accounts: 1, institutions: 1, health: 1));
    });
  });
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AccountsScreen()),
          ),
          child: const Text('open accounts'),
        ),
      ),
    );
  }
}

final class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository({required this.balance});

  double balance;
  bool fail = false;
  Completer<void>? gate;
  int getAccountsCalls = 0;
  int getInstitutionsCalls = 0;

  @override
  Future<Result<List<Account>>> getAccounts() async {
    getAccountsCalls += 1;
    await gate?.future;
    if (fail) {
      return const Failure(NetworkFailure());
    }
    return Success([_account(balance)]);
  }

  @override
  Future<Result<List<Account>>> getFinanciallyActiveAccounts() {
    return getAccounts();
  }

  @override
  Future<Result<List<Institution>>> getInstitutions() async {
    getInstitutionsCalls += 1;
    await gate?.future;
    if (fail) {
      return const Failure(NetworkFailure());
    }
    return Success([_institution()]);
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
  _FakeHealthLoader(this.status);

  PlaidConnectionStatus status;
  DateTime? pendingDisconnectAt;
  bool fail = false;
  int loadCalls = 0;

  Future<Result<List<PlaidConnectionHealth>>> load() async {
    loadCalls += 1;
    if (fail) {
      return const Failure(DatabaseFailure());
    }
    return Success([
      PlaidConnectionHealth(
        connectionId: 'item-1',
        status: status,
        statusReason: status == PlaidConnectionStatus.loginRequired
            ? PlaidConnectionStatusReason.loginRequired
            : null,
        pendingDisconnectAt: pendingDisconnectAt,
      ),
    ]);
  }
}

Account _account(double balance) {
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

Institution _institution() {
  final now = DateTime(2026, 7, 23);

  return Institution(
    id: 'institution-1',
    userId: 'user-1',
    plaidItemId: 'item-1',
    name: 'Test Bank',
    createdAt: now,
    updatedAt: now,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/accounts/controller/account_providers.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_accounts_sync_service.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/entities/institution.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/accounts/domain/repositories/account_repository.dart';
import 'package:ophir/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:ophir/features/accounts/presentation/widgets/accounts_empty_state.dart';
import 'package:ophir/core/widgets/app_compact_switch.dart';

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
      await tester.tap(find.text('Sync'));
      await tester.pumpAndSettle();

      expect(syncedConnectionIds, ['item-1']);
      expect(repository.accounts.single.isIncludedInFinances, isFalse);
      expect(repository.participationUpdates, isEmpty);
    });
  });
}

final class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.repository,
    required this.child,
    this.syncAccounts,
  });

  final AccountRepository repository;
  final Widget child;
  final PlaidAccountsSyncCallback? syncAccounts;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(repository),
        if (syncAccounts != null)
          plaidAccountsSyncCallbackProvider.overrideWithValue(syncAccounts!),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }
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

  @override
  Future<Result<List<Account>>> getAccounts() async {
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

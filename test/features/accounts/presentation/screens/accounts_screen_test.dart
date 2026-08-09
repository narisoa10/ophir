import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/accounts/controller/account_providers.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/accounts/domain/repositories/account_repository.dart';
import 'package:ophir/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:ophir/features/accounts/presentation/widgets/accounts_empty_state.dart';

void main() {
  group('AccountsScreen', () {
    testWidgets(
      'empty accounts show title, empty state, and connect bank action',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(
          _TestApp(
            repository: _FakeAccountRepository(accounts: const []),
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
          ),
          child: const AccountsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Checking'), findsOneWidget);
      expect(find.byType(AccountsEmptyState), findsNothing);
      expect(
        find.widgetWithText(FilledButton, l10n.accountsConnectBank),
        findsOneWidget,
      );
    });
  });
}

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.repository, required this.child});

  final AccountRepository repository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [accountRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }
}

final class _FakeAccountRepository implements AccountRepository {
  const _FakeAccountRepository({required this.accounts});

  final List<Account> accounts;

  @override
  Future<Result<void>> archiveAccount(String accountId) async {
    return const Success(null);
  }

  @override
  Future<Result<Account>> createAccount(Account account) async {
    return Success(account);
  }

  @override
  Future<Result<List<Account>>> createAccounts(List<Account> accounts) async {
    return Success(accounts);
  }

  @override
  Future<Result<List<Account>>> getAccounts() async {
    return Success(accounts);
  }

  @override
  Future<Result<Account>> updateAccount(Account account) async {
    return Success(account);
  }
}

Account _account({required String name}) {
  final now = DateTime(2026, 7, 23);

  return Account(
    id: 'account-1',
    userId: 'user-1',
    name: name,
    type: AccountType.bank,
    currencyCode: 'CAD',
    initialBalance: 100,
    iconKey: 'bank',
    colorKey: 'blue',
    sortOrder: 0,
    isArchived: false,
    createdAt: now,
    updatedAt: now,
  );
}

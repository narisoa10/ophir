import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/services/account_financial_participation_policy.dart';

void main() {
  group('AccountFinancialParticipationPolicy', () {
    const policy = AccountFinancialParticipationPolicy();

    test('treats included accounts as financially active', () {
      final account = _account(isIncludedInFinances: true);

      expect(policy.isFinanciallyActive(account), isTrue);
    });

    test('excludes accounts not included in finances', () {
      final included = _account(id: 'included', isIncludedInFinances: true);
      final excluded = _account(id: 'excluded', isIncludedInFinances: false);

      final activeAccounts = policy.financiallyActiveAccounts([
        included,
        excluded,
      ]);

      expect(activeAccounts, [included]);
    });

    test('supports only CAD accounts', () {
      expect(policy.isCurrencySupported(_account()), isTrue);
      expect(
        policy.isCurrencySupported(_account(currencyCode: 'USD')),
        isFalse,
      );
      expect(
        policy.isCurrencySupported(
          _account(currencyCode: null, unofficialCurrencyCode: 'BTC'),
        ),
        isFalse,
      );
    });

    test('a non-CAD account is never financially active', () {
      final cad = _account(id: 'cad');
      final usd = _account(id: 'usd', currencyCode: 'USD');

      expect(policy.isFinanciallyActive(usd), isFalse);
      expect(policy.financiallyActiveAccounts([cad, usd]), [cad]);
    });
  });
}

Account _account({
  String id = 'account-1',
  bool isIncludedInFinances = true,
  String? currencyCode = 'CAD',
  String? unofficialCurrencyCode,
}) {
  final now = DateTime(2026, 8, 10);

  return Account(
    id: id,
    userId: 'user-1',
    name: 'Checking',
    sortOrder: 0,
    isArchived: false,
    isIncludedInFinances: isIncludedInFinances,
    currencyCode: currencyCode,
    unofficialCurrencyCode: unofficialCurrencyCode,
    createdAt: now,
    updatedAt: now,
  );
}

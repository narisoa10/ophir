import '../../../../core/currency/product_currency.dart';
import '../entities/account.dart';

final class AccountFinancialParticipationPolicy {
  const AccountFinancialParticipationPolicy();

  /// Only an account in [productCurrencyCode] can take part in finances; an
  /// account in another currency keeps that currency and stays out.
  bool isCurrencySupported(Account account) {
    return account.currencyCode == productCurrencyCode;
  }

  bool isFinanciallyActive(Account account) {
    return account.isIncludedInFinances && isCurrencySupported(account);
  }

  List<Account> financiallyActiveAccounts(Iterable<Account> accounts) {
    return accounts.where(isFinanciallyActive).toList(growable: false);
  }
}

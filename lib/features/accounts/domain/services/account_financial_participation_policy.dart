import '../entities/account.dart';

final class AccountFinancialParticipationPolicy {
  const AccountFinancialParticipationPolicy();

  bool isFinanciallyActive(Account account) {
    return account.isIncludedInFinances;
  }

  List<Account> financiallyActiveAccounts(Iterable<Account> accounts) {
    return accounts.where(isFinanciallyActive).toList(growable: false);
  }
}

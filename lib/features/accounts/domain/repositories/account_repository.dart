import '../../../../core/errors/result.dart';
import '../entities/account.dart';

abstract interface class AccountRepository {
  Future<Result<List<Account>>> getAccounts();

  Future<Result<Account>> createAccount(Account account);

  Future<Result<Account>> updateAccount(Account account);

  Future<Result<void>> archiveAccount(String accountId);
}
import '../../../../core/errors/result.dart';
import '../entities/account.dart';
import '../entities/institution.dart';

abstract interface class AccountRepository {
  Future<Result<List<Account>>> getAccounts();

  Future<Result<List<Institution>>> getInstitutions();

  Future<Result<Account>> createAccount(Account account);

  Future<Result<List<Account>>> createAccounts(List<Account> accounts);

  Future<Result<Account>> updateAccount(Account account);

  Future<Result<void>> archiveAccount(String accountId);
}

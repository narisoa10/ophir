import '../../../../core/errors/result.dart';
import '../entities/account.dart';
import '../entities/institution.dart';

abstract interface class AccountRepository {
  Future<Result<List<Account>>> getAccounts();

  Future<Result<List<Account>>> getFinanciallyActiveAccounts();

  Future<Result<List<Institution>>> getInstitutions();

  Future<Result<Account>> updateAccountFinancialParticipation({
    required String accountId,
    required bool isIncludedInFinances,
  });
}

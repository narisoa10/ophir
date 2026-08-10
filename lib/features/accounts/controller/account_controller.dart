import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/account.dart';
import 'account_providers.dart';

final accountControllerProvider =
    AsyncNotifierProvider<AccountController, Result<List<Account>>>(
      AccountController.new,
    );

final class AccountController extends AsyncNotifier<Result<List<Account>>> {
  @override
  Future<Result<List<Account>>> build() async {
    final repository = ref.watch(accountRepositoryProvider);
    return repository.getAccounts();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(accountRepositoryProvider);
      return repository.getAccounts();
    });
  }

  Future<Result<Account>> setFinancialParticipation({
    required String accountId,
    required bool isIncludedInFinances,
  }) async {
    final repository = ref.read(accountRepositoryProvider);
    final result = await repository.updateAccountFinancialParticipation(
      accountId: accountId,
      isIncludedInFinances: isIncludedInFinances,
    );

    if (result is Success<Account>) {
      await refresh();
    }

    return result;
  }
}

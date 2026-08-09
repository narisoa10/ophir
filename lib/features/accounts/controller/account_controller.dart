import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/account.dart';
import '../domain/services/account_visual_defaults.dart';
import 'account_providers.dart';
import 'create_manual_account_command.dart';

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

  Future<Result<Account>> createManualAccount(
    CreateManualAccountCommand command,
  ) async {
    final now = DateTime.now();
    final visualDefaults = AccountVisualDefaults.forType(command.type);

    final account = Account(
      id: '',
      userId: '',
      name: command.name,
      type: command.type,
      currencyCode: command.currencyCode,
      initialBalance: command.initialBalance,
      iconKey: visualDefaults.iconKey,
      colorKey: visualDefaults.colorKey,
      sortOrder: 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    final repository = ref.read(accountRepositoryProvider);
    final result = await repository.createAccount(account);

    if (result is Success<Account>) {
      await refresh();
    }

    return result;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(accountRepositoryProvider);
      return repository.getAccounts();
    });
  }
}

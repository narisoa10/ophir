import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../data/plaid/plaid_accounts_sync_service.dart';
import '../data/plaid/plaid_connect_service.dart';
import '../data/plaid/plaid_connection_health_service.dart';
import '../data/plaid/plaid_item_lifecycle_service.dart';
import '../data/repositories/supabase_account_repository.dart';
import '../domain/entities/account.dart';
import '../domain/entities/institution.dart';
import '../domain/entities/plaid_connection_health.dart';
import '../domain/repositories/account_repository.dart';
import 'last_good_result_notifier.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return SupabaseAccountRepository(Supabase.instance.client);
});

typedef PlaidAccountsSyncCallback =
    Future<Result<PlaidAccountsSyncSummary>> Function(String connectionId);

final plaidAccountsSyncCallbackProvider = Provider<PlaidAccountsSyncCallback>((
  ref,
) {
  final service = PlaidAccountsSyncService(Supabase.instance.client);
  return service.syncAccounts;
});

typedef PlaidItemLifecycleCallback =
    Future<Result<void>> Function(String connectionId);

final plaidItemLifecycleServiceProvider = Provider<PlaidItemLifecycleService>((
  ref,
) {
  return PlaidItemLifecycleService(Supabase.instance.client);
});

final plaidItemDisconnectCallbackProvider =
    Provider<PlaidItemLifecycleCallback>((ref) {
      return ref.watch(plaidItemLifecycleServiceProvider).disconnectItem;
    });

final plaidItemDeleteCallbackProvider = Provider<PlaidItemLifecycleCallback>((
  ref,
) {
  return ref.watch(plaidItemLifecycleServiceProvider).deleteItem;
});

final plaidConnectServiceProvider = Provider<PlaidConnectService>((ref) {
  return PlaidConnectService(Supabase.instance.client);
});

typedef PlaidConnectionHealthLoader =
    Future<Result<List<PlaidConnectionHealth>>> Function();

final plaidConnectionHealthLoaderProvider =
    Provider<PlaidConnectionHealthLoader>((ref) {
      final service = PlaidConnectionHealthService(Supabase.instance.client);
      return service.loadHealth;
    });

final plaidConnectionHealthProvider =
    AsyncNotifierProvider<
      PlaidConnectionHealthNotifier,
      Result<List<PlaidConnectionHealth>>
    >(PlaidConnectionHealthNotifier.new);

final class PlaidConnectionHealthNotifier
    extends AsyncNotifier<Result<List<PlaidConnectionHealth>>>
    with LastGoodResultNotifier<List<PlaidConnectionHealth>> {
  @override
  Future<Result<List<PlaidConnectionHealth>>> build() {
    final loadHealth = ref.watch(plaidConnectionHealthLoaderProvider);
    return loadHealth();
  }
}

final accountsProvider = FutureProvider<Result<List<Account>>>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getAccounts();
});

final accountInstitutionsProvider =
    AsyncNotifierProvider<AccountInstitutionsNotifier, Result<List<Institution>>>(
      AccountInstitutionsNotifier.new,
    );

final class AccountInstitutionsNotifier
    extends AsyncNotifier<Result<List<Institution>>>
    with LastGoodResultNotifier<List<Institution>> {
  @override
  Future<Result<List<Institution>>> build() {
    final repository = ref.watch(accountRepositoryProvider);
    return repository.getInstitutions();
  }
}

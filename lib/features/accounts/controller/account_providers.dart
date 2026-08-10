import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../data/plaid/plaid_accounts_sync_service.dart';
import '../data/plaid/plaid_item_remove_service.dart';
import '../data/repositories/supabase_account_repository.dart';
import '../domain/entities/account.dart';
import '../domain/entities/institution.dart';
import '../domain/repositories/account_repository.dart';

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

typedef PlaidItemRemoveCallback =
    Future<Result<void>> Function(String connectionId);

final plaidItemRemoveCallbackProvider = Provider<PlaidItemRemoveCallback>((
  ref,
) {
  final service = PlaidItemRemoveService(Supabase.instance.client);
  return service.removeItem;
});

final accountsProvider = FutureProvider<Result<List<Account>>>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getAccounts();
});

final accountInstitutionsProvider = FutureProvider<Result<List<Institution>>>((
  ref,
) {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getInstitutions();
});

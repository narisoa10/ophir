import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../data/repositories/supabase_account_repository.dart';
import '../domain/entities/account.dart';
import '../domain/repositories/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return SupabaseAccountRepository(Supabase.instance.client);
});

final accountsProvider = FutureProvider<Result<List<Account>>>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getAccounts();
});
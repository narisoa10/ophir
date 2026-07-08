import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../dto/account_dto.dart';
import '../mappers/account_mapper.dart';

final class SupabaseAccountRepository implements AccountRepository {
  const SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'accounts';

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<Result<List<Account>>> getAccounts() async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('sort_order');

      final accounts = data
          .map((json) => AccountDto.fromJson(json).toEntity())
          .toList(growable: false);

      return Success(accounts);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<Account>> createAccount(Account account) async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final dto = account.toDto();
      final insertJson = dto.toInsertJson()..['user_id'] = userId;

      final data = await _client
          .from(_table)
          .insert(insertJson)
          .select()
          .single();

      return Success(AccountDto.fromJson(data).toEntity());
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<Account>> updateAccount(Account account) async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final dto = account.toDto();

      final data = await _client
          .from(_table)
          .update(dto.toUpdateJson())
          .eq('id', account.id)
          .eq('user_id', userId)
          .select()
          .single();

      return Success(AccountDto.fromJson(data).toEntity());
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> archiveAccount(String accountId) async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      await _client
          .from(_table)
          .update({'is_archived': true})
          .eq('id', accountId)
          .eq('user_id', userId);

      return const Success(null);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }
}
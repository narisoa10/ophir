import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/institution.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/services/account_financial_participation_policy.dart';
import '../dto/account_dto.dart';
import '../dto/institution_dto.dart';
import '../mappers/account_mapper.dart';
import '../mappers/institution_mapper.dart';

final class SupabaseAccountRepository implements AccountRepository {
  const SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'accounts';
  static const _institutionsTable = 'institutions';
  static const _financialParticipationPolicy =
      AccountFinancialParticipationPolicy();

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
  Future<Result<List<Account>>> getFinanciallyActiveAccounts() async {
    final result = await getAccounts();

    return switch (result) {
      Success<List<Account>>(:final value) => Success(
        _financialParticipationPolicy.financiallyActiveAccounts(value),
      ),
      Failure<List<Account>>(:final failure) => Failure(failure),
    };
  }

  @override
  Future<Result<List<Institution>>> getInstitutions() async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final data = await _client
          .from(_institutionsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at');

      final institutions = data
          .map((json) => InstitutionDto.fromJson(json).toEntity())
          .toList(growable: false);

      return Success(institutions);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<Account>> updateAccountFinancialParticipation({
    required String accountId,
    required bool isIncludedInFinances,
  }) async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final data = await _client
          .from(_table)
          .update({'is_included_in_finances': isIncludedInFinances})
          .eq('id', accountId)
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
}

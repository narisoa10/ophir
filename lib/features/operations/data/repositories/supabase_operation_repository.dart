import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/operation.dart';
import '../../domain/repositories/operation_repository.dart';
import '../dto/operation_dto.dart';
import '../mappers/operation_mapper.dart';

final class SupabaseOperationRepository implements OperationRepository {
  const SupabaseOperationRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'operations';

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<Result<List<Operation>>> getOperations() async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .isFilter('archived_at', null)
          .order('occurred_at', ascending: false);

      final operations = data
          .map((json) => OperationDto.fromJson(json).toEntity())
          .toList(growable: false);

      return Success(operations);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<Operation>> createOperation(Operation operation) async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final dto = operation.toDto();
      final insertJson = dto.toInsertJson()..['user_id'] = userId;

      final data = await _client
          .from(_table)
          .insert(insertJson)
          .select()
          .single();

      return Success(OperationDto.fromJson(data).toEntity());
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final dto = operation.toDto();

      final data = await _client
          .from(_table)
          .update(dto.toUpdateJson())
          .eq('id', operation.id)
          .eq('user_id', userId)
          .select()
          .single();

      return Success(OperationDto.fromJson(data).toEntity());
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) async {
    final userId = _currentUserId;

    if (userId == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      await _client
          .from(_table)
          .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', operationId)
          .eq('user_id', userId);

      return const Success(null);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }
}

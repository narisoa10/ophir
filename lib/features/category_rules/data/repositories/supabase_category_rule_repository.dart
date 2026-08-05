import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/category_rule.dart';
import '../../domain/repositories/category_rule_repository.dart';
import '../dto/category_rule_dto.dart';

final class SupabaseCategoryRuleRepository implements CategoryRuleRepository {
  const SupabaseCategoryRuleRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'category_rules';

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<CategoryRule>> getRules() async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    final data = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('merchant_key');

    return data
        .map((json) => CategoryRuleDto.fromJson(json).toEntity())
        .toList(growable: false);
  }

  @override
  Stream<List<CategoryRule>> watchRules() async* {
    final userId = _currentUserId;
    if (userId == null) {
      yield const [];
      return;
    }

    await for (final rows
        in _client
            .from(_table)
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)) {
      final rules =
          rows
              .map((json) => CategoryRuleDto.fromJson(json).toEntity())
              .toList(growable: false)
            ..sort(
              (left, right) => left.merchantKey.compareTo(right.merchantKey),
            );
      yield rules;
    }
  }

  @override
  Future<CategoryRule> upsertRule({
    required String merchantKey,
    required String categoryId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Current user is required.');
    }

    final data = await _client
        .from(_table)
        .upsert({
          'user_id': userId,
          'merchant_key': merchantKey,
          'category_id': categoryId,
        }, onConflict: 'user_id,merchant_key')
        .select()
        .single();

    return CategoryRuleDto.fromJson(data).toEntity();
  }

  @override
  Future<void> deleteRule(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

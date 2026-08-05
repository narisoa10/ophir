import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../operations/controller/operation_providers.dart';
import '../data/repositories/supabase_category_rule_repository.dart';
import '../domain/entities/category_rule.dart';
import '../domain/repositories/category_rule_repository.dart';

final remoteCategoryRuleRepositoryProvider = Provider<CategoryRuleRepository>((
  ref,
) {
  return SupabaseCategoryRuleRepository(Supabase.instance.client);
});

final categoryRulesProvider = StreamProvider<List<CategoryRule>>((ref) {
  ref.watch(operationUserIdProvider);
  final repository = ref.watch(remoteCategoryRuleRepositoryProvider);
  return repository.watchRules();
});

/// Stage 4 — set from Dashboard before navigating to Operations.
final operationReviewFilterEnabledProvider =
    NotifierProvider<OperationReviewFilterEnabledController, bool>(
      OperationReviewFilterEnabledController.new,
    );

final class OperationReviewFilterEnabledController extends Notifier<bool> {
  @override
  bool build() => false;

  set enabled(bool value) => state = value;
}

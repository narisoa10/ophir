import '../entities/category_rule.dart';

abstract interface class CategoryRuleRepository {
  Future<List<CategoryRule>> getRules();

  Stream<List<CategoryRule>> watchRules();

  Future<CategoryRule> upsertRule({
    required String merchantKey,
    required String categoryId,
  });

  Future<void> deleteRule(String id);
}

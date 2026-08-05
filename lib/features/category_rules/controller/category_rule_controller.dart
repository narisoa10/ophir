import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/category_rule_providers.dart';

final categoryRuleControllerProvider =
    AsyncNotifierProvider<CategoryRuleController, void>(
      CategoryRuleController.new,
    );

final class CategoryRuleController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> rememberRule({
    required String merchantKey,
    required String categoryId,
  }) async {
    final repository = ref.read(remoteCategoryRuleRepositoryProvider);
    await repository.upsertRule(
      merchantKey: merchantKey,
      categoryId: categoryId,
    );
  }

  Future<void> deleteRule(String id) async {
    await ref.read(remoteCategoryRuleRepositoryProvider).deleteRule(id);
  }
}

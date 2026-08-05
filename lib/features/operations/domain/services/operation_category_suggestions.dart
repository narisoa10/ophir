import '../../../../core/categories/app_categories.dart';
import '../../../category_rules/domain/entities/category_rule.dart';
import '../../../category_rules/domain/utils/merchant_key.dart';
import '../entities/operation.dart';
import '../enums/operation_type.dart';
import '../utils/operation_needs_categorization.dart';

/// Stage 1 — up to 3 category chips for bank-sync review.
List<AppCategory> suggestOperationCategories({
  required Operation operation,
  required List<Operation> allOperations,
  required List<CategoryRule> categoryRules,
}) {
  final available = _categoriesFor(operation.type);
  final suggestions = <AppCategory>[];
  final merchantKey = normalizeMerchantKey(operation.note);

  void add(AppCategory? category) {
    if (category == null || !available.contains(category)) {
      return;
    }
    if (suggestions.any((item) => item.id == category.id)) {
      return;
    }
    suggestions.add(category);
  }

  if (merchantKey.isNotEmpty) {
    for (final rule in categoryRules) {
      if (rule.merchantKey == merchantKey) {
        add(AppCategories.byIdName(rule.categoryId));
      }
    }

    final counts = <String, int>{};
    for (final other in allOperations) {
      if (other.id == operation.id || operationNeedsCategorization(other)) {
        continue;
      }
      if (normalizeMerchantKey(other.note) != merchantKey) {
        continue;
      }
      final categoryId = other.categoryId;
      if (categoryId == null) {
        continue;
      }
      counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    }

    final ranked = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    for (final entry in ranked) {
      add(AppCategories.byIdName(entry.key));
      if (suggestions.length >= 3) {
        return suggestions;
      }
    }
  }

  return suggestions.take(3).toList(growable: false);
}

List<AppCategory> _categoriesFor(OperationType type) {
  return switch (type) {
    OperationType.expense => AppCategories.expenseCategories,
    OperationType.income => AppCategories.incomeCategories,
    OperationType.transfer => AppCategories.expenseCategories,
  };
}

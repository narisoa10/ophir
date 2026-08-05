import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/features/category_rules/domain/entities/category_rule.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/services/operation_category_suggestions.dart';

void main() {
  test('suggestOperationCategories prefers saved merchant rule', () {
    final now = DateTime(2026, 8, 1);
    final target = _operation(
      id: 'target',
      note: 'Costco',
      categoryId: AppCategoryId.expenseOtherUncategorized.name,
    );
    final rules = [
      CategoryRule(
        id: 'rule-1',
        userId: 'user-1',
        merchantKey: 'costco',
        categoryId: AppCategoryId.expenseFoodGroceries.name,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final suggestions = suggestOperationCategories(
      operation: target,
      allOperations: const [],
      categoryRules: rules,
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.first.id, AppCategoryId.expenseFoodGroceries);
  });
}

Operation _operation({
  required String id,
  required String? note,
  required String categoryId,
}) {
  final now = DateTime(2026, 8, 1);

  return Operation(
    id: id,
    userId: 'user-1',
    type: OperationType.expense,
    amount: 10,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
    note: note,
  );
}

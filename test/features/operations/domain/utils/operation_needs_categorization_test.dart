import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/utils/operation_needs_categorization.dart';
import 'package:ophir/features/operations/presentation/filters/operation_review_filter.dart';

void main() {
  group('operationNeedsCategorization', () {
    test('does not flag uncategorized manual expense operations', () {
      final operation = _operation(
        categoryId: AppCategoryId.expenseOtherUncategorized.name,
      );

      expect(operationNeedsCategorization(operation), isFalse);
    });

    test('does not flag generic manual income operations', () {
      final operation = _operation(
        type: OperationType.income,
        categoryId: AppCategoryId.incomeOtherIncomeOtherIncome.name,
      );

      expect(operationNeedsCategorization(operation), isFalse);
    });

    test('ignores manual operations', () {
      final operation = _operation(
        categoryId: AppCategoryId.expenseOtherUncategorized.name,
      );

      expect(operationNeedsCategorization(operation), isFalse);
    });

    test('ignores overridden operations', () {
      final operation = _operation(
        categoryId: AppCategoryId.expenseOtherUncategorized.name,
        categoryOverridden: true,
      );

      expect(operationNeedsCategorization(operation), isFalse);
    });
  });

  group('OperationReviewFilter', () {
    test('returns no operations when enabled in manual-only mode', () {
      const filter = OperationReviewFilter(enabled: true);
      final operations = [
        _operation(
          id: '1',
          categoryId: AppCategoryId.expenseOtherUncategorized.name,
        ),
        _operation(
          id: '2',
          categoryId: AppCategoryId.expenseFoodGroceries.name,
        ),
      ];

      final result = filter.apply(operations);

      expect(result, isEmpty);
    });
  });
}

Operation _operation({
  String id = 'op-1',
  OperationType type = OperationType.expense,
  String categoryId = 'expenseFoodGroceries',
  bool categoryOverridden = false,
}) {
  final now = DateTime(2026, 8, 1);

  return Operation(
    id: id,
    userId: 'user-1',
    type: type,
    amount: 10,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
    categoryOverridden: categoryOverridden,
  );
}

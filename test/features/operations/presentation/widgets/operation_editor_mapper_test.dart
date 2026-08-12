import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_editor_mapper.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_editor_result.dart';

void main() {
  group('operationFromEditorResult', () {
    test('marks manual category changes as overridden', () {
      final existing = _operation(
        categoryId: AppCategoryId.expenseFoodGroceries.name,
      );

      final updated = operationFromEditorResult(
        result: OperationEditorResult.saved(
          type: OperationType.expense,
          amount: 42,
          currencyCode: 'CAD',
          occurredAt: existing.occurredAt,
          recurrence: OperationRecurrence.none,
          categoryId: AppCategoryId.expenseFoodRestaurant.name,
          note: 'Costco',
        ),
        existingOperation: existing,
      );

      expect(updated.categoryOverridden, isTrue);
      expect(updated.source, OperationSource.manual);
    });

    test('preserves Plaid source when editing an existing operation', () {
      final existing = _operation(
        categoryId: AppCategoryId.expenseFoodGroceries.name,
        source: OperationSource.plaid,
      );

      final updated = operationFromEditorResult(
        result: OperationEditorResult.saved(
          type: OperationType.expense,
          amount: 42,
          currencyCode: 'CAD',
          occurredAt: existing.occurredAt,
          recurrence: OperationRecurrence.none,
          categoryId: AppCategoryId.expenseFoodRestaurant.name,
          note: 'Costco',
        ),
        existingOperation: existing,
      );

      expect(updated.source, OperationSource.plaid);
    });
  });
}

Operation _operation({
  required String categoryId,
  OperationSource source = OperationSource.manual,
}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: 'operation-1',
    userId: 'user-1',
    source: source,
    type: OperationType.expense,
    amount: 42,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
    note: 'Costco',
  );
}

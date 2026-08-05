import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_editor_result.dart';

void main() {
  group('OperationEditorResult', () {
    test('stores editable operation values', () {
      final date = DateTime.utc(2026, 1, 15);
      final result = OperationEditorResult.saved(
        type: OperationType.expense,
        amount: 42.50,
        currencyCode: 'CAD',
        occurredAt: date,
        categoryId: AppCategoryId.expenseFoodGroceries.name,
        recurrence: OperationRecurrence.monthly,
        note: 'Groceries',
      );

      expect(result.isArchived, isFalse);
      expect(result.type, OperationType.expense);
      expect(result.amount, 42.50);
      expect(result.currencyCode, 'CAD');
      expect(result.occurredAt, date);
      expect(result.categoryId, AppCategoryId.expenseFoodGroceries.name);
      expect(result.recurrence, OperationRecurrence.monthly);
      expect(result.note, 'Groceries');
    });

    test('preserves nullable editable values', () {
      final result = OperationEditorResult.saved(
        type: OperationType.income,
        amount: 100,
        currencyCode: 'USD',
        occurredAt: DateTime.utc(2026),
        categoryId: null,
        recurrence: OperationRecurrence.none,
        note: null,
      );

      expect(result.categoryId, isNull);
      expect(result.note, isNull);
    });

    test('stores archive action without editable values', () {
      const result = OperationEditorResult.archived();

      expect(result.isArchived, isTrue);
      expect(result.type, isNull);
      expect(result.amount, isNull);
      expect(result.currencyCode, isNull);
      expect(result.occurredAt, isNull);
      expect(result.categoryId, isNull);
      expect(result.recurrence, isNull);
      expect(result.note, isNull);
    });
  });
}

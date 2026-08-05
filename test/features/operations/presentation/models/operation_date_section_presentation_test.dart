import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/presentation/models/operation_date_section_presentation.dart';

void main() {
  group('operationDateSectionsFor', () {
    test('groups operations by calendar date and preserves item order', () {
      final sections = operationDateSectionsFor([
        _operation(
          id: 'expense-1',
          amount: 10,
          occurredAt: DateTime(2026, 1, 1, 9),
          type: OperationType.expense,
        ),
        _operation(
          id: 'income-1',
          amount: 5,
          occurredAt: DateTime(2026, 1, 1, 18),
          type: OperationType.income,
        ),
        _operation(
          id: 'income-2',
          amount: 50,
          occurredAt: DateTime(2026, 1, 2),
          type: OperationType.income,
        ),
      ]);

      expect(sections, hasLength(2));
      expect(sections.first.date, DateTime(2026));
      expect(sections.first.operations.map((operation) => operation.id), [
        'expense-1',
        'income-1',
      ]);
      expect(sections.last.date, DateTime(2026, 1, 2));
      expect(sections.last.operations.single.id, 'income-2');
    });

    test(
      'calculates running balances by date without presentation adapter',
      () {
        final sections = operationDateSectionsFor([
          _operation(
            id: 'expense-1',
            amount: 10,
            occurredAt: DateTime(2026),
            type: OperationType.expense,
          ),
          _operation(
            id: 'income-1',
            amount: 25,
            occurredAt: DateTime(2026, 1, 2),
            type: OperationType.income,
          ),
        ]);

        expect(sections.first.runningBalanceAfterDate, -10);
        expect(sections.last.runningBalanceAfterDate, 15);
      },
    );
  });
}

Operation _operation({
  required String id,
  required double amount,
  required DateTime occurredAt,
  required OperationType type,
}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: id,
    userId: 'user',
    type: type,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: occurredAt,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: AppCategoryId.expenseFoodGroceries.name,
  );
}

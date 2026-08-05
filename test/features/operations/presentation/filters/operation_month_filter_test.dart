import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/utils/operation_calendar_date.dart';
import 'package:ophir/features/operations/presentation/filters/operation_month_filter.dart';
import 'package:ophir/features/operations/presentation/models/operation_date_section_presentation.dart';

void main() {
  group('OperationMonthFilter', () {
    test('shows only operations in selected month', () {
      final filter = OperationMonthFilter(
        selectedMonth: DateTime(2026, 8),
        now: DateTime(2026, 8, 1),
      );
      final operations = [
        _operation(id: 'august', occurredAt: DateTime(2026, 8, 15)),
        _operation(id: 'july', occurredAt: DateTime(2026, 7, 31)),
      ];

      final visible = filter.operationsInMonth(operations);

      expect(visible.map((operation) => operation.id), ['august']);
    });

    test('includes manual operations using local month rule', () {
      final filter = OperationMonthFilter(
        selectedMonth: DateTime(2026, 7),
        now: DateTime(2026, 8, 1),
      );
      final operations = [
        _operation(id: 'manual-july', occurredAt: DateTime(2026, 7, 10)),
        _operation(id: 'manual-august', occurredAt: DateTime(2026, 8, 1)),
      ];

      final visible = filter.operationsInMonth(operations);

      expect(visible.map((operation) => operation.id), ['manual-july']);
    });

    test('uses the same manual calendar date as date sections', () {
      final filter = OperationMonthFilter(
        selectedMonth: DateTime(2026, 8),
        now: DateTime(2026, 8, 1),
      );
      final operation = _operation(
        id: 'manual-august-third-day',
        occurredAt: DateTime.utc(2026, 8, 3),
      );

      final visible = filter.operationsInMonth([operation]);
      final sections = operationDateSectionsFor(visible);

      expect(operationCalendarDate(operation), DateTime(2026, 8, 3));
      expect(sections.single.date, operationCalendarDate(operation));
    });

    test('preserves local month semantics', () {
      final filter = OperationMonthFilter(
        selectedMonth: DateTime(2026, 8),
        now: DateTime(2026, 8, 1),
      );
      final operations = [
        _operation(
          id: 'manual-july-local',
          occurredAt: DateTime(2026, 7, 31, 20),
        ),
        _operation(id: 'manual-august-local', occurredAt: DateTime(2026, 8, 1)),
      ];

      final visible = filter.operationsInMonth(operations);

      expect(visible.map((operation) => operation.id), ['manual-august-local']);
    });

    test('keeps ordinary manual operation in August section', () {
      final filter = OperationMonthFilter(
        selectedMonth: DateTime(2026, 8),
        now: DateTime(2026, 8, 3),
      );
      final operation = _operation(
        id: 'manual-august-third-day',
        occurredAt: DateTime(2026, 8, 3, 12),
      );

      final visible = filter.operationsInMonth([operation]);
      final sections = operationDateSectionsFor(visible);

      expect(visible.single.id, 'manual-august-third-day');
      expect(sections.single.date, DateTime(2026, 8, 3));
    });

    test('handles manual month boundaries by local calendar day', () {
      final filter = OperationMonthFilter(
        selectedMonth: DateTime(2026, 8),
        now: DateTime(2026, 9, 1),
      );
      final operations = [
        _operation(id: 'first-day', occurredAt: DateTime(2026, 8, 1)),
        _operation(id: 'last-day', occurredAt: DateTime(2026, 8, 31)),
        _operation(id: 'next-month', occurredAt: DateTime(2026, 9, 1)),
      ];

      final visible = filter.operationsInMonth(operations);

      expect(visible.map((operation) => operation.id), [
        'first-day',
        'last-day',
      ]);
    });

    test('blocks forward navigation beyond current month', () {
      final filter = OperationMonthFilter(
        selectedMonth: DateTime(2026, 8),
        now: DateTime(2026, 8, 1),
      );

      expect(filter.canGoForward, isFalse);
      expect(
        OperationMonthFilter(
          selectedMonth: DateTime(2026, 7),
          now: DateTime(2026, 8, 1),
        ).canGoForward,
        isTrue,
      );
    });

    test('blocks back navigation before earliest operation month', () {
      final filter = OperationMonthFilter(
        selectedMonth: DateTime(2026, 5),
        now: DateTime(2026, 8, 1),
      );
      final operations = [
        _operation(id: 'may', occurredAt: DateTime(2026, 5, 2)),
        _operation(id: 'july', occurredAt: DateTime(2026, 7, 2)),
      ];

      expect(filter.canGoBack(operations), isFalse);
      expect(
        OperationMonthFilter(
          selectedMonth: DateTime(2026, 7),
          now: DateTime(2026, 8, 1),
        ).canGoBack(operations),
        isTrue,
      );
    });
  });
}

Operation _operation({required String id, required DateTime occurredAt}) {
  final now = DateTime(2026, 8, 1, 12);

  return Operation(
    id: id,
    userId: 'user-1',
    type: OperationType.expense,
    amount: 10,
    currencyCode: 'CAD',
    occurredAt: occurredAt,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/utils/operation_calendar_date.dart';

void main() {
  group('operationCalendarDate', () {
    test('uses local calendar date for manual operations', () {
      final operation = _operation(occurredAt: DateTime(2026, 7, 31, 15));

      expect(operationCalendarDate(operation), DateTime(2026, 7, 31));
    });

    test('uses UTC value calendar fields without timezone conversion', () {
      final operation = _operation(occurredAt: DateTime.utc(2026, 8, 3));

      expect(operationCalendarDate(operation), DateTime(2026, 8, 3));
    });

    test('serializes operation date as YYYY-MM-DD', () {
      expect(operationDateToJson(DateTime(2026, 8, 3, 20)), '2026-08-03');
    });

    test('deserializes operation date from YYYY-MM-DD', () {
      expect(operationDateFromJson('2026-08-03'), DateTime(2026, 8, 3));
    });

    test('deserializes legacy ISO by date prefix', () {
      expect(
        operationDateFromJson('2026-08-03T00:00:00.000+04:00'),
        DateTime(2026, 8, 3),
      );
    });
  });
}

Operation _operation({required DateTime occurredAt}) {
  final now = DateTime.utc(2026, 8, 1);

  return Operation(
    id: 'operation',
    userId: 'user',
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

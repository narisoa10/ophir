import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/utils/operation_write_rules.dart';

Operation _operation(
  OperationType type, {
  String? fromAccountId,
  String? toAccountId,
  OperationSource source = OperationSource.manual,
}) {
  final now = DateTime.utc(2026, 10, 3);
  return Operation(
    id: 'op-1',
    userId: 'user-1',
    type: type,
    amount: 10,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    source: source,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
  );
}

void main() {
  group('isUserWritableOperation', () {
    test('allows income and expense, with or without a source account', () {
      expect(isUserWritableOperation(_operation(OperationType.income)), isTrue);
      expect(
        isUserWritableOperation(_operation(OperationType.expense)),
        isTrue,
      );
      expect(
        isUserWritableOperation(
          _operation(OperationType.expense, fromAccountId: 'acc-1'),
        ),
        isTrue,
      );
    });

    test('rejects a transfer from any source', () {
      for (final source in OperationSource.values) {
        expect(
          isUserWritableOperation(
            _operation(
              OperationType.transfer,
              fromAccountId: 'acc-1',
              toAccountId: 'acc-2',
              source: source,
            ),
          ),
          isFalse,
          reason: source.name,
        );
      }
    });

    test('rejects income or expense with a destination account', () {
      for (final type in [OperationType.income, OperationType.expense]) {
        expect(
          isUserWritableOperation(_operation(type, toAccountId: 'acc-2')),
          isFalse,
          reason: type.name,
        );
      }
    });

    test('transfer stays parseable for system and legacy rows', () {
      expect(OperationType.fromJson('transfer'), OperationType.transfer);
      expect(OperationType.transfer.toJson(), 'transfer');
    });
  });
}

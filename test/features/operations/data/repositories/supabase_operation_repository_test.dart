import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/operations/data/repositories/supabase_operation_repository.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseOperationRepository', () {
    // Unreachable endpoint: a request reaching the network would fail
    // differently from the expected ValidationFailure.
    final client = SupabaseClient('http://127.0.0.1:9', 'test-anon-key');
    final repository = SupabaseOperationRepository(client);

    final now = DateTime.utc(2026, 10, 3);
    final transfer = Operation(
      id: 'op-1',
      userId: 'user-1',
      type: OperationType.transfer,
      amount: 10,
      currencyCode: 'CAD',
      occurredAt: now,
      recurrence: OperationRecurrence.none,
      isRecurring: false,
      createdAt: now,
      updatedAt: now,
      fromAccountId: 'acc-1',
      toAccountId: 'acc-2',
    );

    tearDownAll(client.dispose);

    test('createOperation rejects a transfer before any request', () async {
      final result = await repository.createOperation(transfer);

      expect((result as Failure<Operation>).failure, isA<ValidationFailure>());
    });

    test('updateOperation rejects a transfer before any request', () async {
      final result = await repository.updateOperation(transfer);

      expect((result as Failure<Operation>).failure, isA<ValidationFailure>());
    });

    test(
      'a writable expense passes the guard and reaches the auth check',
      () async {
        final expense = Operation(
          id: 'op-2',
          userId: 'user-1',
          type: OperationType.expense,
          amount: 10,
          currencyCode: 'CAD',
          occurredAt: now,
          recurrence: OperationRecurrence.none,
          isRecurring: false,
          createdAt: now,
          updatedAt: now,
        );

        final result = await repository.createOperation(expense);

        expect(
          (result as Failure<Operation>).failure,
          isA<UnauthorizedFailure>(),
        );
      },
    );
  });
}

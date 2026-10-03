import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/operations/data/repositories/local_operation_repository.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  group('LocalOperationRepository', () {
    late AppDatabase database;
    late LocalOperationRepository repository;
    const userId = 'user-123';

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = LocalOperationRepository(database: database, userId: userId);
    });

    tearDown(() async {
      await database.close();
    });

    test('createOperation preserves manual source and category', () async {
      final now = DateTime.now().toUtc();
      final operation = Operation(
        id: 'op-1',
        userId: userId,
        type: OperationType.expense,
        amount: 100,
        currencyCode: 'USD',
        occurredAt: now,
        recurrence: OperationRecurrence.none,
        isRecurring: false,
        createdAt: now,
        updatedAt: now,
        source: OperationSource.manual,
        categoryId: AppCategoryId.expenseHousingRent.name,
      );

      final result = await repository.createOperation(operation);

      expect(result.isSuccess, isTrue);
      final returnedOp = (result as Success<Operation>).value;
      expect(returnedOp.source, OperationSource.manual);
      expect(returnedOp.categoryId, AppCategoryId.expenseHousingRent.name);

      final savedOp = await database.getOperationById('op-1');
      expect(savedOp, isNotNull);
      expect(savedOp!.source, OperationSource.manual);
      expect(savedOp.categoryId, AppCategoryId.expenseHousingRent.name);
    });

    Operation operation({
      required String id,
      required OperationType type,
      String? fromAccountId,
      String? toAccountId,
    }) {
      final now = DateTime.now().toUtc();
      return Operation(
        id: id,
        userId: userId,
        type: type,
        amount: 25,
        currencyCode: 'CAD',
        occurredAt: now,
        recurrence: OperationRecurrence.none,
        isRecurring: false,
        createdAt: now,
        updatedAt: now,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        categoryId: type == OperationType.transfer
            ? null
            : AppCategoryId.expenseHousingRent.name,
      );
    }

    test('createOperation saves manual income and expense', () async {
      for (final type in [OperationType.income, OperationType.expense]) {
        final result = await repository.createOperation(
          operation(id: 'op-${type.name}', type: type),
        );

        expect(result.isSuccess, isTrue, reason: type.name);
        expect(await database.getOperationById('op-${type.name}'), isNotNull);
      }
    });

    test('createOperation rejects a transfer and saves nothing', () async {
      final result = await repository.createOperation(
        operation(
          id: 'op-transfer',
          type: OperationType.transfer,
          fromAccountId: 'acc-1',
          toAccountId: 'acc-2',
        ),
      );

      expect(result, isA<Failure<Operation>>());
      expect((result as Failure<Operation>).failure, isA<ValidationFailure>());
      expect(await database.getOperationById('op-transfer'), isNull);
    });

    test(
      'updateOperation rejects turning an expense into a transfer',
      () async {
        final created = await repository.createOperation(
          operation(id: 'op-2', type: OperationType.expense),
        );
        expect(created.isSuccess, isTrue);

        final result = await repository.updateOperation(
          operation(
            id: 'op-2',
            type: OperationType.transfer,
            fromAccountId: 'acc-1',
            toAccountId: 'acc-2',
          ),
        );

        expect(
          (result as Failure<Operation>).failure,
          isA<ValidationFailure>(),
        );
        final saved = await database.getOperationById('op-2');
        expect(saved!.type, OperationType.expense);
        expect(saved.toAccountId, isNull);
      },
    );

    test('a synced system transfer is still stored for display', () async {
      final transfer = Operation(
        id: 'op-system',
        userId: userId,
        source: OperationSource.plaid,
        type: OperationType.transfer,
        amount: 40,
        currencyCode: 'CAD',
        occurredAt: DateTime.utc(2026, 10, 1),
        recurrence: OperationRecurrence.none,
        isRecurring: false,
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
        fromAccountId: 'acc-1',
        toAccountId: 'acc-2',
      );

      final result = await repository.saveSyncedOperation(transfer);

      expect(result.isSuccess, isTrue);
      final saved = await database.getOperationById('op-system');
      expect(saved!.type, OperationType.transfer);
      expect(saved.toAccountId, 'acc-2');
    });
  });
}

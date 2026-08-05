import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
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
  });
}

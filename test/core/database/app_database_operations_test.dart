import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/database/app_database.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  group('AppDatabase operations', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('saves and reads operation', () async {
      await database.saveOperation(_operation(id: 'operation-1'));

      final operation = await database.getOperationById('operation-1');

      expect(operation?.id, 'operation-1');
      expect(operation?.amount, 100);
    });

    test('watches operations', () async {
      final values = <List<Operation>>[];
      final subscription = database
          .watchOperations('user-1')
          .listen(values.add);
      addTearDown(subscription.cancel);

      await database.saveOperation(_operation(id: 'operation-1'));
      await Future<void>.delayed(Duration.zero);

      expect(values.last.map((operation) => operation.id), ['operation-1']);
    });

    test('does not mix different users', () async {
      await database.saveOperation(
        _operation(id: 'operation-1', userId: 'user-1'),
      );
      await database.saveOperation(
        _operation(id: 'operation-2', userId: 'user-2'),
      );

      final operations = await database.getOperations('user-1');

      expect(operations.map((operation) => operation.id), ['operation-1']);
    });

    test('stores categoryId as AppCategoryId.name', () async {
      await database.saveOperation(
        _operation(
          id: 'operation-1',
          categoryId: AppCategoryId.expenseFoodGroceries.name,
        ),
      );

      final operation = await database.getOperationById('operation-1');

      expect(operation?.categoryId, AppCategoryId.expenseFoodGroceries.name);
    });

    test('allows transfer with null categoryId', () async {
      await database.saveOperation(
        _operation(
          id: 'transfer-1',
          type: OperationType.transfer,
          categoryId: null,
          toAccountId: 'account-2',
        ),
      );

      final operation = await database.getOperationById('transfer-1');

      expect(operation?.categoryId, isNull);
      expect(operation?.type, OperationType.transfer);
    });

    test('replaceOperations does not create duplicates', () async {
      await database.replaceOperations('user-1', [
        _operation(id: 'operation-1', amount: 100),
      ]);
      await database.replaceOperations('user-1', [
        _operation(id: 'operation-1', amount: 200),
      ]);

      final operations = await database.getOperations('user-1');

      expect(operations, hasLength(1));
      expect(operations.single.amount, 200);
    });

    test(
      'replaceOperations preserves pending and failed local operations',
      () async {
        await database.saveOperation(_operation(id: 'pending-1', amount: 100));
        await database.saveOperation(_operation(id: 'failed-1', amount: 200));
        await database.markOperationSyncFailed('failed-1');
        await database.replaceOperations('user-1', [
          _operation(id: 'remote-1', amount: 300),
        ]);

        final operations = await database.getOperations('user-1');

        expect(
          operations.map((operation) => operation.id),
          unorderedEquals(['pending-1', 'failed-1', 'remote-1']),
        );
      },
    );

    test(
      'replaceOperations removes synced operations missing remotely',
      () async {
        await database.replaceOperations('user-1', [
          _operation(id: 'remote-1', amount: 100),
        ]);
        await database.replaceOperations('user-1', [
          _operation(id: 'remote-2', amount: 200),
        ]);

        final operations = await database.getOperations('user-1');

        expect(operations.map((operation) => operation.id), ['remote-2']);
      },
    );

    test('round-trip for manual source', () async {
      final op = _operation(
        id: 'operation-roundtrip',
        source: OperationSource.manual,
      );
      await database.saveOperation(op);

      final retrieved = await database.getOperationById('operation-roundtrip');

      expect(retrieved?.source, OperationSource.manual);
    });
  });
}

Operation _operation({
  required String id,
  String userId = 'user-1',
  String? categoryId,
  OperationType type = OperationType.expense,
  String? toAccountId,
  double amount = 100,
  OperationSource source = OperationSource.manual,
  String? externalId,
  bool isPending = false,
}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: id,
    userId: userId,
    fromAccountId: 'account-1',
    toAccountId: toAccountId,
    categoryId: type == OperationType.transfer
        ? categoryId
        : categoryId ?? AppCategoryId.expenseHousingRent.name,
    type: type,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    source: source,
    externalId: externalId,
    isPending: isPending,
  );
}

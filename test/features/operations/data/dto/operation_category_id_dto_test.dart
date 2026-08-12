import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/features/operations/data/dto/operation_dto.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';

void main() {
  group('OperationDto Supabase category_id', () {
    test('writes AppCategoryId.name for insert and update', () {
      final dto = _operationDto(
        categoryId: AppCategoryId.expenseTransportationFuel.name,
      );

      expect(
        dto.toInsertJson()['category_id'],
        AppCategoryId.expenseTransportationFuel.name,
      );
      expect(
        dto.toUpdateJson()['category_id'],
        AppCategoryId.expenseTransportationFuel.name,
      );
    });

    test('reads AppCategoryId.name', () {
      final dto = OperationDto.fromJson(
        _operationJson(
          categoryId: AppCategoryId.incomeEmploymentSalary.name,
          type: 'income',
        ),
      );

      expect(dto.categoryId, AppCategoryId.incomeEmploymentSalary.name);
    });

    test('allows null category_id for transfer', () {
      final dto = _operationDto(categoryId: null, type: 'transfer');

      expect(dto.toInsertJson()['category_id'], isNull);
      expect(
        OperationDto.fromJson(
          _operationJson(categoryId: null, type: 'transfer'),
        ).categoryId,
        isNull,
      );
    });

    test('rejects UUID and dot stable_key', () {
      expect(
        () => _operationDto(
          categoryId: '00000000-0000-0000-0000-000000000000',
        ).toInsertJson(),
        throwsArgumentError,
      );
      expect(
        () => OperationDto.fromJson(
          _operationJson(categoryId: 'expense.transportation.fuel'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('OperationDto manual serialization', () {
    test('serializes manual fields to JSON properly', () {
      final dto = _operationDto(categoryOverridden: true);

      final insertJson = dto.toInsertJson();
      final updateJson = dto.toUpdateJson();

      expect(insertJson['id'], 'operation-1');
      expect(insertJson['user_id'], 'user-1');
      expect(insertJson['from_account_id'], 'account-1');
      expect(insertJson['to_account_id'], isNull);
      expect(insertJson['category_id'], isNull);
      expect(insertJson['type'], 'expense');
      expect(insertJson['amount'], 100);
      expect(insertJson['currency_code'], 'CAD');
      expect(insertJson['occurred_at'], '2026-01-01');
      expect(insertJson['recurrence'], 'none');
      expect(insertJson['is_recurring'], isFalse);
      expect(insertJson['note'], isNull);
      expect(insertJson['source'], 'manual');
      expect(insertJson['category_overridden'], isTrue);
      expect(insertJson, isNot(contains('external_id')));
      expect(insertJson, isNot(contains('is_pending')));

      expect(updateJson['from_account_id'], 'account-1');
      expect(updateJson['to_account_id'], isNull);
      expect(updateJson['category_id'], isNull);
      expect(updateJson['type'], 'expense');
      expect(updateJson['amount'], 100);
      expect(updateJson['currency_code'], 'CAD');
      expect(updateJson['occurred_at'], '2026-01-01');
      expect(updateJson['recurrence'], 'none');
      expect(updateJson['is_recurring'], isFalse);
      expect(updateJson['note'], isNull);
      expect(updateJson['source'], 'manual');
      expect(updateJson['category_overridden'], isTrue);
      expect(updateJson, isNot(contains('external_id')));
      expect(updateJson, isNot(contains('is_pending')));
    });

    test('deserializes manual fields from JSON properly', () {
      final dto = OperationDto.fromJson(
        _operationJson(source: 'manual', categoryOverridden: true),
      );

      expect(dto.id, 'operation-1');
      expect(dto.userId, 'user-1');
      expect(dto.fromAccountId, 'account-1');
      expect(dto.toAccountId, isNull);
      expect(dto.categoryId, isNull);
      expect(dto.type, 'expense');
      expect(dto.amount, 100);
      expect(dto.currencyCode, 'CAD');
      expect(dto.occurredAt, DateTime(2026));
      expect(dto.recurrence, 'none');
      expect(dto.isRecurring, isFalse);
      expect(dto.note, isNull);
      expect(dto.source, OperationSource.manual);
      expect(dto.categoryOverridden, isTrue);
    });

    test('deserializes legacy ISO date by calendar date prefix', () {
      final dto = OperationDto.fromJson(
        _operationJson(
          occurredAt: '2026-08-03T00:00:00.000Z',
          source: 'manual',
        ),
      );

      expect(dto.occurredAt, DateTime(2026, 8, 3));
    });

    test('deserializes offset ISO date by original calendar date prefix', () {
      final dto = OperationDto.fromJson(
        _operationJson(
          occurredAt: '2026-08-03T00:00:00.000+04:00',
          source: 'manual',
        ),
      );

      expect(dto.occurredAt, DateTime(2026, 8, 3));
    });

    test('uses defaults for missing values', () {
      final dto = OperationDto.fromJson(_operationJson());

      expect(dto.source, OperationSource.manual);
      expect(dto.externalId, isNull);
      expect(dto.isPending, isFalse);
      expect(dto.categoryOverridden, isFalse);
    });

    test('deserializes Plaid source without requiring a category', () {
      final dto = OperationDto.fromJson(
        _operationJson(
          categoryId: null,
          source: 'plaid',
          categoryOverridden: false,
        ),
      );

      expect(dto.source, OperationSource.plaid);
      expect(dto.categoryId, isNull);
    });

    test('serializes Plaid source using canonical operation fields only', () {
      final dto = _operationDto(source: OperationSource.plaid);

      final insertJson = dto.toInsertJson();
      final updateJson = dto.toUpdateJson();

      expect(insertJson['source'], 'plaid');
      expect(updateJson['source'], 'plaid');
    });

    test('rejects unknown source values', () {
      expect(
        () => OperationDto.fromJson(_operationJson(source: 'future-source')),
        throwsArgumentError,
      );
    });
  });
}

OperationDto _operationDto({
  String? categoryId,
  String type = 'expense',
  OperationSource source = OperationSource.manual,
  String? externalId,
  bool isPending = false,
  bool categoryOverridden = false,
}) {
  final now = DateTime.utc(2026);

  return OperationDto(
    id: 'operation-1',
    userId: 'user-1',
    fromAccountId: 'account-1',
    toAccountId: type == 'transfer' ? 'account-2' : null,
    categoryId: categoryId,
    type: type,
    amount: 100,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: 'none',
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    source: source,
    externalId: externalId,
    isPending: isPending,
    categoryOverridden: categoryOverridden,
  );
}

Map<String, dynamic> _operationJson({
  String? categoryId,
  String type = 'expense',
  String? source,
  String? externalId,
  bool? isPending,
  bool? categoryOverridden,
  String occurredAt = '2026-01-01',
}) {
  return {
    'id': 'operation-1',
    'user_id': 'user-1',
    'from_account_id': 'account-1',
    'to_account_id': type == 'transfer' ? 'account-2' : null,
    'category_id': categoryId,
    'type': type,
    'amount': 100,
    'currency_code': 'CAD',
    'occurred_at': occurredAt,
    'recurrence': 'none',
    'is_recurring': false,
    'note': null,
    'created_at': '2026-01-01T00:00:00.000Z',
    'updated_at': '2026-01-01T00:00:00.000Z',
    'source': source,
    'external_id': externalId,
    'is_pending': isPending,
    'category_overridden': categoryOverridden,
  };
}

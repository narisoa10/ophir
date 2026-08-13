import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/operations/data/dto/operation_dto.dart';
import 'package:ophir/features/operations/data/mappers/operation_mapper.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/services/operation_finance_service.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_list_tile.dart';

void main() {
  group('OperationSource.plaidInternalTransfer', () {
    test('fromJson parses plaid_internal_transfer', () {
      expect(
        OperationSource.fromJson('plaid_internal_transfer'),
        OperationSource.plaidInternalTransfer,
      );
    });

    test('toJson serializes plaid_internal_transfer', () {
      expect(
        OperationSource.plaidInternalTransfer.toJson(),
        'plaid_internal_transfer',
      );
    });

    test('manual and plaid mappings remain unchanged', () {
      expect(OperationSource.fromJson('manual'), OperationSource.manual);
      expect(OperationSource.fromJson('plaid'), OperationSource.plaid);
      expect(OperationSource.manual.toJson(), 'manual');
      expect(OperationSource.plaid.toJson(), 'plaid');
    });
  });

  group('OperationDto plaid_internal_transfer', () {
    test('deserializes synthetic transfer without crash', () {
      final now = DateTime.utc(2026);
      final dto = OperationDto.fromJson({
        'id': 'op-synthetic',
        'user_id': 'user-1',
        'source': 'plaid_internal_transfer',
        'from_account_id': 'acc-out',
        'to_account_id': 'acc-in',
        'category_id': null,
        'type': 'transfer',
        'amount': 100,
        'currency_code': 'USD',
        'occurred_at': '2026-01-01',
        'recurrence': 'none',
        'is_recurring': false,
        'note': null,
        'category_overridden': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      expect(dto.source, OperationSource.plaidInternalTransfer);
      expect(dto.type, 'transfer');
      expect(dto.categoryId, isNull);
      expect(dto.toEntity().source, OperationSource.plaidInternalTransfer);
    });

    test('serializes synthetic source', () {
      final dto = OperationDto.fromJson({
        'id': 'op-synthetic',
        'user_id': 'user-1',
        'source': 'plaid_internal_transfer',
        'from_account_id': 'acc-out',
        'to_account_id': 'acc-in',
        'category_id': null,
        'type': 'transfer',
        'amount': 50,
        'currency_code': 'USD',
        'occurred_at': '2026-01-02',
        'recurrence': 'none',
        'is_recurring': false,
        'category_overridden': false,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });

      expect(dto.toInsertJson()['source'], 'plaid_internal_transfer');
      expect(dto.toUpdateJson()['source'], 'plaid_internal_transfer');
    });
  });

  group('Finance neutrality for synthetic transfer', () {
    test('transfer source does not affect finance totals', () {
      const finance = OperationFinanceService();
      final now = DateTime.utc(2026);
      final ops = [
        Operation(
          id: 'e1',
          userId: 'u',
          source: OperationSource.manual,
          fromAccountId: 'a',
          categoryId: AppCategoryId.expenseHousingRent.name,
          type: OperationType.expense,
          amount: 40,
          currencyCode: 'USD',
          occurredAt: now,
          recurrence: OperationRecurrence.none,
          isRecurring: false,
          createdAt: now,
          updatedAt: now,
        ),
        Operation(
          id: 't1',
          userId: 'u',
          source: OperationSource.plaidInternalTransfer,
          fromAccountId: 'a',
          toAccountId: 'b',
          categoryId: null,
          type: OperationType.transfer,
          amount: 999,
          currencyCode: 'USD',
          occurredAt: now,
          recurrence: OperationRecurrence.none,
          isRecurring: false,
          createdAt: now,
          updatedAt: now,
        ),
        Operation(
          id: 'i1',
          userId: 'u',
          source: OperationSource.plaid,
          fromAccountId: 'a',
          categoryId: AppCategoryId.incomeEmploymentSalary.name,
          type: OperationType.income,
          amount: 10,
          currencyCode: 'USD',
          occurredAt: now,
          recurrence: OperationRecurrence.none,
          isRecurring: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      expect(finance.totalBalance(ops), -30);
    });
  });

  group('OperationListTile synthetic transfer', () {
    testWidgets('renders transfer tile for plaid_internal_transfer', (
      tester,
    ) async {
      final now = DateTime.utc(2026);
      final operation = Operation(
        id: 't1',
        userId: 'u',
        source: OperationSource.plaidInternalTransfer,
        fromAccountId: 'a',
        toAccountId: 'b',
        categoryId: null,
        type: OperationType.transfer,
        amount: 75,
        currencyCode: 'USD',
        occurredAt: now,
        recurrence: OperationRecurrence.none,
        isRecurring: false,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: OperationListTile(operation: operation)),
        ),
      );

      expect(find.byType(OperationListTile), findsOneWidget);
      expect(find.textContaining('75'), findsOneWidget);
    });
  });
}

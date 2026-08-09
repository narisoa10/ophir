import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/accounts/data/dto/account_dto.dart';
import 'package:ophir/features/accounts/data/mappers/account_mapper.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';

void main() {
  group('Account mapper', () {
    test('round-trips account fields', () {
      final now = DateTime(2026, 7, 23);
      final account = Account(
        id: 'account-1',
        userId: 'user-1',
        name: 'Checking',
        type: AccountType.bank,
        currencyCode: 'CAD',
        initialBalance: 120,
        iconKey: 'bank',
        colorKey: 'blue',
        sortOrder: 0,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final dto = account.toDto();
      final entity = dto.toEntity();

      expect(dto.id, 'account-1');
      expect(dto.userId, 'user-1');
      expect(dto.name, 'Checking');
      expect(dto.type, 'bank');
      expect(dto.currencyCode, 'CAD');
      expect(dto.initialBalance, 120);
      expect(entity.name, 'Checking');
      expect(entity.type, AccountType.bank);
    });

    test('insert omits absent Plaid fields and update preserves nulls', () {
      final dto = AccountDto(
        id: 'account-1',
        userId: 'user-1',
        name: 'Checking',
        type: 'bank',
        currencyCode: 'CAD',
        initialBalance: 120,
        iconKey: 'bank',
        colorKey: 'blue',
        sortOrder: 0,
        isArchived: false,
        createdAt: DateTime(2026, 7, 23),
        updatedAt: DateTime(2026, 7, 23),
      );

      final insertJson = dto.toInsertJson();
      final updateJson = dto.toUpdateJson();

      expect(insertJson, {
        'user_id': 'user-1',
        'name': 'Checking',
        'type': 'bank',
        'currency_code': 'CAD',
        'initial_balance': 120,
        'icon_key': 'bank',
        'color_key': 'blue',
        'sort_order': 0,
        'is_archived': false,
      });
      expect(updateJson, {
        'name': 'Checking',
        'type': 'bank',
        'currency_code': 'CAD',
        'unofficial_currency_code': null,
        'initial_balance': 120,
        'icon_key': 'bank',
        'color_key': 'blue',
        'sort_order': 0,
        'is_archived': false,
        'plaid_item_id': null,
        'institution_id': null,
        'plaid_account_id': null,
        'official_name': null,
        'mask': null,
        'plaid_type': null,
        'plaid_subtype': null,
        'current_balance': null,
        'available_balance': null,
        'balance_fetched_at': null,
      });
      expect(insertJson, isNot(contains('external_id')));
      expect(insertJson, isNot(contains('unofficial_currency_code')));
      expect(insertJson, isNot(contains('institution_id')));
      expect(insertJson, isNot(contains('plaid_item_id')));
      expect(insertJson, isNot(contains('plaid_account_id')));
      expect(insertJson, isNot(contains('official_name')));
      expect(insertJson, isNot(contains('mask')));
      expect(insertJson, isNot(contains('plaid_type')));
      expect(insertJson, isNot(contains('plaid_subtype')));
      expect(insertJson, isNot(contains('current_balance')));
      expect(insertJson, isNot(contains('available_balance')));
      expect(insertJson, isNot(contains('balance_fetched_at')));
      expect(updateJson, isNot(contains('external_id')));
    });
  });
}

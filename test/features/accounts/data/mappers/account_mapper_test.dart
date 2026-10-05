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
        plaidItemId: 'plaid-item-1',
        institutionId: 'institution-1',
        plaidAccountId: 'plaid-account-1',
        officialName: 'Plaid Checking',
        mask: '1234',
        plaidType: 'depository',
        plaidSubtype: 'checking',
        currentBalance: 120,
        sortOrder: 0,
        isArchived: false,
        isIncludedInFinances: false,
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
      expect(dto.plaidAccountId, 'plaid-account-1');
      expect(dto.currentBalance, 120);
      expect(dto.isIncludedInFinances, isFalse);
      expect(entity.name, 'Checking');
      expect(entity.type, AccountType.bank);
      expect(entity.plaidAccountId, 'plaid-account-1');
      expect(entity.isIncludedInFinances, isFalse);
    });

    test('reads financial participation from json', () {
      final dto = AccountDto.fromJson({
        'id': 'account-1',
        'user_id': 'user-1',
        'name': 'Checking',
        'type': 'bank',
        'currency_code': 'CAD',
        'unofficial_currency_code': null,
        'initial_balance': null,
        'icon_key': null,
        'color_key': null,
        'sort_order': 0,
        'is_archived': false,
        'is_included_in_finances': false,
        'created_at': '2026-07-23T00:00:00.000Z',
        'updated_at': '2026-07-23T00:00:00.000Z',
        'plaid_item_id': 'plaid-item-1',
        'institution_id': 'institution-1',
        'plaid_account_id': 'plaid-account-1',
        'official_name': 'Plaid Checking',
        'mask': '1234',
        'plaid_type': 'depository',
        'plaid_subtype': 'checking',
        'current_balance': 120,
        'available_balance': null,
        'balance_fetched_at': null,
      });

      final entity = dto.toEntity();

      expect(dto.isIncludedInFinances, isFalse);
      expect(entity.isIncludedInFinances, isFalse);
      expect(entity.plaidAccountId, 'plaid-account-1');
      expect(dto.plaidMissingSince, isNull);
      expect(entity.plaidMissingSince, isNull);
    });

    test('reads plaid_missing_since from json', () {
      final dto = AccountDto.fromJson({
        'id': 'account-1',
        'user_id': 'user-1',
        'name': 'Checking',
        'sort_order': 0,
        'is_archived': false,
        'created_at': '2026-07-23T00:00:00.000Z',
        'updated_at': '2026-07-23T00:00:00.000Z',
        'plaid_account_id': 'plaid-account-1',
        'current_balance': 120,
        'balance_fetched_at': '2026-10-01T10:00:00.000Z',
        'plaid_missing_since': '2026-10-02T10:00:00.000Z',
      });

      final entity = dto.toEntity();

      expect(
        entity.plaidMissingSince,
        DateTime.utc(2026, 10, 2, 10).toLocal(),
      );
      expect(entity.currentBalance, 120);
      expect(entity.plaidMissingSince!.isUtc, isFalse);
    });

    test('round-trips plaid_missing_since', () {
      final now = DateTime(2026, 7, 23);
      final missingSince = DateTime(2026, 10, 2, 6);
      final account = Account(
        id: 'account-1',
        userId: 'user-1',
        name: 'Checking',
        plaidAccountId: 'plaid-account-1',
        sortOrder: 0,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
        plaidMissingSince: missingSince,
      );

      expect(account.toDto().plaidMissingSince, missingSince);
      expect(account.toDto().toEntity().plaidMissingSince, missingSince);
    });
  });
}

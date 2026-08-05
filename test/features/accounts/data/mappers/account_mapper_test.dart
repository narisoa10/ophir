import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/accounts/data/dto/account_dto.dart';
import 'package:ophir/features/accounts/data/mappers/account_mapper.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/enums/account_source.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';

void main() {
  group('Account mapper', () {
    test('round-trips manual account fields', () {
      final now = DateTime(2026, 7, 23);
      final account = Account(
        id: 'account-1',
        userId: 'user-1',
        name: 'Checking',
        type: AccountType.bank,
        source: AccountSource.manual,
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
      expect(dto.source, 'manual');
      expect(dto.currencyCode, 'CAD');
      expect(dto.initialBalance, 120);
      expect(entity.name, 'Checking');
      expect(entity.type, AccountType.bank);
      expect(entity.source, AccountSource.manual);
    });

    test('insert and update json include manual account fields only', () {
      final dto = AccountDto(
        id: 'account-1',
        userId: 'user-1',
        name: 'Checking',
        type: 'bank',
        source: 'manual',
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
        'source': 'manual',
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
        'source': 'manual',
        'currency_code': 'CAD',
        'initial_balance': 120,
        'icon_key': 'bank',
        'color_key': 'blue',
        'sort_order': 0,
        'is_archived': false,
      });
      expect(insertJson, isNot(contains('external_id')));
      expect(insertJson, isNot(contains('institution_id')));
      expect(updateJson, isNot(contains('external_id')));
      expect(updateJson, isNot(contains('institution_id')));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/operations/data/dto/internal_transfer_review_item_dto.dart';

void main() {
  group('InternalTransferReviewItemDto', () {
    test('H2-1 parses valid candidate payload', () {
      final dto = InternalTransferReviewItemDto.fromJson(_validPayload());
      final item = dto.toEntity();

      expect(item.reconciliationId, '22222222-2222-4222-8222-222222222222');
      expect(item.state, 'candidate');
      expect(item.amount, 100);
      expect(item.currencyCode, 'USD');
      expect(item.outgoingDate, DateTime(2026, 8, 14));
      expect(item.incomingDate, DateTime(2026, 8, 14));
      expect(item.outgoingAccount.displayName, 'Checking A');
      expect(item.outgoingAccount.mask, '1234');
      expect(item.outgoingAccount.available, isTrue);
      expect(item.incomingAccount.displayName, 'Savings A');
      expect(item.outgoingOperation?.type, 'expense');
      expect(item.incomingOperation?.type, 'income');
      expect(item.outgoingOperation?.note, 'leg-out');
      expect(item.isInconsistent, isFalse);
      expect(item.transferOperationId, isNull);
    });

    test('H2-2 unavailable/malformed nested account falls back safely', () {
      final payload = _validPayload();
      payload['outgoing_account'] = {
        'id': 'acc-1',
        'display_name': null,
        'mask': '',
        'available': false,
      };
      payload['incoming_account'] = 'not-a-map';

      final item = InternalTransferReviewItemDto.fromJson(payload).toEntity();

      expect(item.outgoingAccount.available, isFalse);
      expect(item.outgoingAccount.displayName, isNull);
      expect(item.outgoingAccount.mask, isNull);
      expect(item.incomingAccount.available, isFalse);
      expect(item.incomingAccount.displayName, isNull);
    });
  });
}

Map<String, dynamic> _validPayload() {
  return {
    'reconciliation_id': '22222222-2222-4222-8222-222222222222',
    'state': 'candidate',
    'transfer_operation_id': null,
    'amount': 100.0,
    'currency_code': 'USD',
    'outgoing_date': '2026-08-14',
    'incoming_date': '2026-08-14',
    'outgoing_account': {
      'id': 'acc-out',
      'display_name': 'Checking A',
      'mask': '1234',
      'available': true,
    },
    'incoming_account': {
      'id': 'acc-in',
      'display_name': 'Savings A',
      'mask': '1234',
      'available': true,
    },
    'outgoing_operation': {
      'id': 'op-out',
      'note': 'leg-out',
      'amount': 100.0,
      'type': 'expense',
      'occurred_at': '2026-08-14',
      'archived': false,
    },
    'incoming_operation': {
      'id': 'op-in',
      'note': 'leg-in',
      'amount': 100.0,
      'type': 'income',
      'occurred_at': '2026-08-14',
      'archived': false,
    },
    'is_inconsistent': false,
    'inconsistency_code': null,
  };
}

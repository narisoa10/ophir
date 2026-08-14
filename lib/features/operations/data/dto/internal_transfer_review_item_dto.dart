import '../../domain/entities/internal_transfer_review_item.dart';
import '../../domain/utils/operation_calendar_date.dart';

final class InternalTransferReviewItemDto {
  const InternalTransferReviewItemDto({
    required this.reconciliationId,
    required this.state,
    required this.amount,
    required this.currencyCode,
    required this.outgoingDate,
    required this.incomingDate,
    required this.outgoingAccount,
    required this.incomingAccount,
    this.outgoingOperation,
    this.incomingOperation,
    this.transferOperationId,
    this.isInconsistent = false,
    this.inconsistencyCode,
  });

  final String reconciliationId;
  final String state;
  final double amount;
  final String currencyCode;
  final DateTime outgoingDate;
  final DateTime incomingDate;
  final InternalTransferReviewAccountDto outgoingAccount;
  final InternalTransferReviewAccountDto incomingAccount;
  final InternalTransferReviewOperationDto? outgoingOperation;
  final InternalTransferReviewOperationDto? incomingOperation;
  final String? transferOperationId;
  final bool isInconsistent;
  final String? inconsistencyCode;

  factory InternalTransferReviewItemDto.fromJson(Map<String, dynamic> json) {
    return InternalTransferReviewItemDto(
      reconciliationId: json['reconciliation_id'] as String,
      state: json['state'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      outgoingDate: _dateFromJson(json['outgoing_date']),
      incomingDate: _dateFromJson(json['incoming_date']),
      outgoingAccount: InternalTransferReviewAccountDto.fromJson(
        _asStringKeyedMap(json['outgoing_account']),
      ),
      incomingAccount: InternalTransferReviewAccountDto.fromJson(
        _asStringKeyedMap(json['incoming_account']),
      ),
      outgoingOperation: _optionalOperation(json['outgoing_operation']),
      incomingOperation: _optionalOperation(json['incoming_operation']),
      transferOperationId: json['transfer_operation_id'] as String?,
      isInconsistent: json['is_inconsistent'] as bool? ?? false,
      inconsistencyCode: json['inconsistency_code'] as String?,
    );
  }

  InternalTransferReviewItem toEntity() {
    return InternalTransferReviewItem(
      reconciliationId: reconciliationId,
      state: state,
      amount: amount,
      currencyCode: currencyCode,
      outgoingDate: outgoingDate,
      incomingDate: incomingDate,
      outgoingAccount: outgoingAccount.toEntity(),
      incomingAccount: incomingAccount.toEntity(),
      outgoingOperation: outgoingOperation?.toEntity(),
      incomingOperation: incomingOperation?.toEntity(),
      transferOperationId: transferOperationId,
      isInconsistent: isInconsistent,
      inconsistencyCode: inconsistencyCode,
    );
  }

  static InternalTransferReviewOperationDto? _optionalOperation(Object? value) {
    if (value == null) {
      return null;
    }
    final map = _asStringKeyedMap(value);
    // H1: operation jsonb may be null; malformed non-map is treated as absent.
    if (map == null) {
      return null;
    }
    return InternalTransferReviewOperationDto.fromJson(map);
  }
}

final class InternalTransferReviewAccountDto {
  const InternalTransferReviewAccountDto({
    required this.available,
    this.id,
    this.displayName,
    this.mask,
  });

  final String? id;
  final String? displayName;
  final String? mask;
  final bool available;

  /// Nested account objects are display-safe; malformed/missing maps fall back.
  factory InternalTransferReviewAccountDto.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return const InternalTransferReviewAccountDto(available: false);
    }

    final displayName = json['display_name'];
    final mask = json['mask'];
    final id = json['id'];
    final available = json['available'];

    return InternalTransferReviewAccountDto(
      id: id is String ? id : null,
      displayName: displayName is String && displayName.trim().isNotEmpty
          ? displayName.trim()
          : null,
      mask: mask is String && mask.trim().isNotEmpty ? mask.trim() : null,
      available: available is bool ? available : false,
    );
  }

  InternalTransferReviewAccount toEntity() {
    return InternalTransferReviewAccount(
      id: id,
      displayName: displayName,
      mask: mask,
      available: available,
    );
  }
}

final class InternalTransferReviewOperationDto {
  const InternalTransferReviewOperationDto({
    required this.id,
    required this.amount,
    required this.type,
    required this.occurredAt,
    required this.archived,
    this.note,
  });

  final String id;
  final String? note;
  final double amount;
  final String type;
  final DateTime occurredAt;
  final bool archived;

  factory InternalTransferReviewOperationDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return InternalTransferReviewOperationDto(
      id: json['id'] as String,
      note: json['note'] as String?,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      occurredAt: _dateFromJson(json['occurred_at']),
      archived: json['archived'] as bool? ?? false,
    );
  }

  InternalTransferReviewOperation toEntity() {
    return InternalTransferReviewOperation(
      id: id,
      note: note,
      amount: amount,
      type: type,
      occurredAt: occurredAt,
      archived: archived,
    );
  }
}

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return null;
}

DateTime _dateFromJson(Object? value) {
  if (value is DateTime) {
    return operationCalendarDateValue(value);
  }
  if (value is String) {
    return operationDateFromJson(value);
  }
  throw FormatException('Invalid review date', value);
}

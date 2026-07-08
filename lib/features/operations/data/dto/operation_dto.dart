final class OperationDto {
  const OperationDto({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.currencyCode,
    required this.occurredAt,
    required this.recurrence,
    required this.isRecurring,
    required this.createdAt,
    required this.updatedAt,
    this.fromAccountId,
    this.toAccountId,
    this.categoryId,
    this.note,
  });

  final String id;
  final String userId;
  final String? fromAccountId;
  final String? toAccountId;
  final String? categoryId;
  final String type;
  final double amount;
  final String currencyCode;
  final DateTime occurredAt;
  final String recurrence;
  final bool isRecurring;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory OperationDto.fromJson(Map<String, dynamic> json) {
    return OperationDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fromAccountId: json['from_account_id'] as String?,
      toAccountId: json['to_account_id'] as String?,
      categoryId: json['category_id'] as String?,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
      recurrence: json['recurrence'] as String,
      isRecurring: json['is_recurring'] as bool,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'currency_code': currencyCode,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'recurrence': recurrence,
      'is_recurring': isRecurring,
      'note': note,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'currency_code': currencyCode,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'recurrence': recurrence,
      'is_recurring': isRecurring,
      'note': note,
    };
  }
}

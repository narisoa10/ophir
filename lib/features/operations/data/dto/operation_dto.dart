import '../../../../core/categories/app_categories.dart';
import '../../domain/enums/operation_source.dart';
import '../../domain/utils/operation_calendar_date.dart';

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
    required this.source,
    required this.isPending,
    this.fromAccountId,
    this.toAccountId,
    this.categoryId,
    this.note,
    this.externalId,
    this.categoryOverridden = false,
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
  final OperationSource source;
  final String? externalId;
  final bool isPending;
  final bool categoryOverridden;

  factory OperationDto.fromJson(Map<String, dynamic> json) {
    return OperationDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fromAccountId: json['from_account_id'] as String?,
      toAccountId: json['to_account_id'] as String?,
      categoryId: _categoryIdFromJson(json['category_id'] as String?),
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      occurredAt: operationDateFromJson(json['occurred_at'] as String),
      recurrence: json['recurrence'] as String,
      isRecurring: json['is_recurring'] as bool,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      source: OperationSource.fromJson(json['source'] as String? ?? 'manual'),
      externalId: json['external_id'] as String?,
      isPending: json['is_pending'] as bool? ?? false,
      categoryOverridden: json['category_overridden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'id': id,
      'user_id': userId,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'category_id': _categoryIdToJson(categoryId),
      'type': type,
      'amount': amount,
      'currency_code': currencyCode,
      'occurred_at': operationDateToJson(occurredAt),
      'recurrence': recurrence,
      'is_recurring': isRecurring,
      'note': note,
      'source': source.toJson(),
      'category_overridden': categoryOverridden,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'category_id': _categoryIdToJson(categoryId),
      'type': type,
      'amount': amount,
      'currency_code': currencyCode,
      'occurred_at': operationDateToJson(occurredAt),
      'recurrence': recurrence,
      'is_recurring': isRecurring,
      'note': note,
      'source': source.toJson(),
      'category_overridden': categoryOverridden,
    };
  }

  static String? _categoryIdFromJson(String? value) {
    if (value == null) {
      return null;
    }

    final category = AppCategories.byIdName(value);

    if (category == null) {
      throw ArgumentError.value(value, 'category_id', 'Unknown category');
    }

    return category.id.name;
  }

  static String? _categoryIdToJson(String? value) {
    if (value == null) {
      return null;
    }

    final category = AppCategories.byIdName(value);

    if (category == null) {
      throw ArgumentError.value(value, 'categoryId', 'Unknown category');
    }

    return category.id.name;
  }
}

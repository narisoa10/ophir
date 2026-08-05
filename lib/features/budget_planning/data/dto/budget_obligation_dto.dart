import 'package:flutter/foundation.dart';

import '../../../../core/categories/app_categories.dart';

@immutable
final class BudgetObligationDto {
  const BudgetObligationDto({
    required this.id,
    required this.setupId,
    required this.userId,
    required this.obligationType,
    required this.amount,
    required this.currencyCode,
    required this.frequency,
    required this.isOverdue,
    required this.source,
    required this.confidence,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.frequencyInterval,
    this.timesPerYear,
    this.nextDueDate,
    this.minimumDebtPayment,
    this.name,
    this.note,
  });

  factory BudgetObligationDto.fromJson(Map<String, dynamic> json) {
    return BudgetObligationDto(
      id: json['id'] as String,
      setupId: json['setup_id'] as String,
      userId: json['user_id'] as String,
      categoryId: _categoryIdFromJson(json['category_id'] as String?),
      obligationType: json['obligation_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      frequency: json['frequency'] as String,
      frequencyInterval: json['frequency_interval'] as int?,
      timesPerYear: json['times_per_year'] as int?,
      nextDueDate: json['next_due_date'] == null
          ? null
          : DateTime.parse(json['next_due_date'] as String),
      minimumDebtPayment: json['minimum_debt_payment'] == null
          ? null
          : (json['minimum_debt_payment'] as num).toDouble(),
      name: json['name'] as String?,
      isOverdue: json['is_overdue'] as bool,
      source: json['source'] as String,
      confidence: json['confidence'] as String,
      isActive: json['is_active'] as bool,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String setupId;
  final String userId;
  final String? categoryId;
  final String obligationType;
  final double amount;
  final String currencyCode;
  final String frequency;
  final int? frequencyInterval;
  final int? timesPerYear;
  final DateTime? nextDueDate;
  final double? minimumDebtPayment;
  final String? name;
  final bool isOverdue;
  final String source;
  final String confidence;
  final bool isActive;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setup_id': setupId,
      'user_id': userId,
      'category_id': _categoryIdToJson(categoryId),
      'obligation_type': obligationType,
      'amount': amount,
      'currency_code': currencyCode,
      'frequency': frequency,
      'frequency_interval': frequencyInterval,
      'times_per_year': timesPerYear,
      'next_due_date': nextDueDate?.toIso8601String(),
      'minimum_debt_payment': minimumDebtPayment,
      'name': name,
      'is_overdue': isOverdue,
      'source': source,
      'confidence': confidence,
      'is_active': isActive,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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

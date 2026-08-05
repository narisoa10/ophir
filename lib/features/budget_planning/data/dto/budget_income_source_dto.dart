import 'package:flutter/foundation.dart';

import '../../../../core/categories/app_categories.dart';

@immutable
final class BudgetIncomeSourceDto {
  const BudgetIncomeSourceDto({
    required this.id,
    required this.setupId,
    required this.userId,
    required this.name,
    required this.amount,
    required this.currencyCode,
    required this.frequency,
    required this.source,
    required this.confidence,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.frequencyInterval,
    this.timesPerYear,
    this.nextDate,
  });

  factory BudgetIncomeSourceDto.fromJson(Map<String, dynamic> json) {
    return BudgetIncomeSourceDto(
      id: json['id'] as String,
      setupId: json['setup_id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      categoryId: _categoryIdFromJson(json['category_id'] as String?),
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      frequency: json['frequency'] as String,
      frequencyInterval: json['frequency_interval'] as int?,
      timesPerYear: json['times_per_year'] as int?,
      nextDate: json['next_date'] == null
          ? null
          : DateTime.parse(json['next_date'] as String),
      source: json['source'] as String,
      confidence: json['confidence'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String setupId;
  final String userId;
  final String name;
  final String? categoryId;
  final double amount;
  final String currencyCode;
  final String frequency;
  final int? frequencyInterval;
  final int? timesPerYear;
  final DateTime? nextDate;
  final String source;
  final String confidence;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setup_id': setupId,
      'user_id': userId,
      'name': name,
      'category_id': _categoryIdToJson(categoryId),
      'amount': amount,
      'currency_code': currencyCode,
      'frequency': frequency,
      'frequency_interval': frequencyInterval,
      'times_per_year': timesPerYear,
      'next_date': nextDate?.toIso8601String(),
      'source': source,
      'confidence': confidence,
      'is_active': isActive,
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

import 'package:flutter/foundation.dart';

import '../enums/budget_data_confidence.dart';
import '../enums/budget_data_source.dart';
import '../enums/budget_frequency.dart';

@immutable
final class BudgetIncomeSource {
  const BudgetIncomeSource({
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
    this.categoryId,
    this.frequencyInterval,
    this.timesPerYear,
    this.nextDate,
  });

  final String id;
  final String setupId;
  final String userId;
  final String name;
  final String? categoryId;
  final double amount;
  final String currencyCode;
  final BudgetFrequency frequency;
  final int? frequencyInterval;
  final int? timesPerYear;
  final DateTime? nextDate;
  final BudgetDataSource source;
  final BudgetDataConfidence confidence;
  final bool isActive;
}

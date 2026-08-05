import 'package:flutter/foundation.dart';

import '../enums/budget_data_confidence.dart';
import '../enums/budget_data_source.dart';
import '../enums/budget_frequency.dart';

@immutable
final class BudgetObligation {
  const BudgetObligation({
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
    this.categoryId,
    this.frequencyInterval,
    this.timesPerYear,
    this.nextDueDate,
    this.minimumDebtPayment,
    this.name,
    this.note,
  });

  final String id;
  final String setupId;
  final String userId;
  final String? categoryId;
  final String obligationType;
  final double amount;
  final String currencyCode;
  final BudgetFrequency frequency;
  final int? frequencyInterval;
  final int? timesPerYear;
  final DateTime? nextDueDate;
  final double? minimumDebtPayment;
  final String? name;
  final bool isOverdue;
  final BudgetDataSource source;
  final BudgetDataConfidence confidence;
  final bool isActive;
  final String? note;
}

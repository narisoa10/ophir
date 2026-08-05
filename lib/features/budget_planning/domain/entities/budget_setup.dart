import 'package:flutter/foundation.dart';

import 'budget_household.dart';
import 'budget_income_source.dart';
import 'budget_obligation.dart';

@immutable
final class BudgetSetup {
  const BudgetSetup({
    required this.id,
    required this.userId,
    required this.status,
    required this.version,
    required this.currentStep,
    required this.household,
    required this.incomeSources,
    required this.obligations,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String status;
  final int version;
  final int currentStep;
  final BudgetHousehold household;
  final List<BudgetIncomeSource> incomeSources;
  final List<BudgetObligation> obligations;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

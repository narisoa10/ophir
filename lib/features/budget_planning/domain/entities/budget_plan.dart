import 'package:flutter/foundation.dart';

import '../enums/budget_data_confidence.dart';
import '../enums/budget_financial_state.dart';

@immutable
final class BudgetPlan {
  const BudgetPlan({
    required this.setupId,
    required this.userId,
    required this.currencyCode,
    required this.reliableMonthlyIncome,
    required this.monthlyMandatoryExpenses,
    required this.monthlyDebtMinimums,
    required this.totalMandatoryLoad,
    required this.freeAmount,
    required this.freeRatio,
    required this.mandatoryLoadRatio,
    required this.financialState,
    required this.dataConfidence,
    required this.calculatedAt,
  });

  final String setupId;
  final String userId;
  final String currencyCode;
  final double reliableMonthlyIncome;
  final double monthlyMandatoryExpenses;
  final double monthlyDebtMinimums;
  final double totalMandatoryLoad;
  final double freeAmount;
  final double freeRatio;
  final double mandatoryLoadRatio;
  final BudgetFinancialState financialState;
  final BudgetDataConfidence dataConfidence;
  final DateTime calculatedAt;
}

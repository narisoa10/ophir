import '../../../assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'dashboard_financial_summary.dart';
import 'dashboard_special_action_totals.dart';

final class DashboardCompatibilityReadModel {
  const DashboardCompatibilityReadModel({
    required this.legacySummary,
    required this.intelligenceOutput,
  });

  final DashboardFinancialSummary legacySummary;
  final FinancialBehaviorCompatibilityOutput? intelligenceOutput;

  bool get hasIntelligenceComparison {
    return intelligenceOutput != null;
  }

  double get legacyExpenseTotal {
    return legacySummary.cashFlow.expenses;
  }

  double? get intelligenceOrdinarySpendingTotal {
    return intelligenceOutput?.totals.ordinarySpendingTotal;
  }

  double? get legacyVsIntelligenceDifference {
    return intelligenceOutput?.totals.legacyVsIntelligenceDifference;
  }

  DashboardSpecialActionTotals? get specialActionTotals {
    final totals = intelligenceOutput?.totals;

    if (totals == null) {
      return null;
    }

    return DashboardSpecialActionTotals(
      assetBuildingTotal: totals.assetBuildingTotal,
      debtReductionTotal: totals.debtReductionTotal,
      cashMovementTotal: totals.cashMovementTotal,
      dataAdjustmentTotal: totals.dataAdjustmentTotal,
      contextRequiredTotal: totals.contextRequiredTotal,
    );
  }
}

import 'financial_behavior_facts_snapshot.dart';
import 'financial_behavior_model_type.dart';
import 'financial_behavior_totals.dart';

final class FinancialBehaviorCompatibilityOutput {
  const FinancialBehaviorCompatibilityOutput({
    required this.snapshot,
    required this.totals,
  });

  final FinancialBehaviorFactsSnapshot snapshot;
  final FinancialBehaviorTotals totals;

  double valueFor(FinancialBehaviorModelType type) {
    return switch (type) {
      FinancialBehaviorModelType.intelligenceOrdinarySpendingTotal =>
        totals.ordinarySpendingTotal,
      FinancialBehaviorModelType.assetBuildingTotal =>
        totals.assetBuildingTotal,
      FinancialBehaviorModelType.debtReductionTotal =>
        totals.debtReductionTotal,
      FinancialBehaviorModelType.contextRequiredTotal =>
        totals.contextRequiredTotal,
      FinancialBehaviorModelType.behavioralSavingsTotal =>
        totals.behavioralSavingsTotal,
      FinancialBehaviorModelType.legacyVsIntelligenceDifference =>
        totals.legacyVsIntelligenceDifference,
    };
  }
}

final class FinancialBehaviorTotals {
  const FinancialBehaviorTotals({
    required this.legacyExpenseTotal,
    required this.ordinarySpendingTotal,
    required this.assetBuildingTotal,
    required this.debtReductionTotal,
    required this.cashMovementTotal,
    required this.dataAdjustmentTotal,
    required this.contextRequiredTotal,
    required this.behavioralSavingsTotal,
    required this.legacyVsIntelligenceDifference,
    required this.unresolvedCount,
  });

  final double legacyExpenseTotal;
  final double ordinarySpendingTotal;
  final double assetBuildingTotal;
  final double debtReductionTotal;
  final double cashMovementTotal;
  final double dataAdjustmentTotal;
  final double contextRequiredTotal;
  final double behavioralSavingsTotal;
  final double legacyVsIntelligenceDifference;
  final int unresolvedCount;
}

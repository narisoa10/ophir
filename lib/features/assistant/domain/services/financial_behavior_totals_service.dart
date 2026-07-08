import '../../../operations/domain/enums/operation_type.dart';
import '../entities/financial_behavior_compatibility_output.dart';
import '../entities/financial_behavior_fact_kind.dart';
import '../entities/financial_behavior_facts_snapshot.dart';
import '../entities/financial_behavior_totals.dart';
import '../entities/financial_model_period.dart';

final class FinancialBehaviorTotalsService {
  const FinancialBehaviorTotalsService();

  FinancialBehaviorTotals totalsFor({
    required FinancialBehaviorFactsSnapshot snapshot,
    required FinancialModelPeriod period,
  }) {
    var legacyExpenseTotal = 0.0;
    var ordinarySpendingTotal = 0.0;
    var assetBuildingTotal = 0.0;
    var debtReductionTotal = 0.0;
    var cashMovementTotal = 0.0;
    var dataAdjustmentTotal = 0.0;
    var contextRequiredTotal = 0.0;
    var unresolvedCount = 0;

    for (final fact in snapshot.facts.where(
      (fact) => period.contains(fact.occurredAt),
    )) {
      if (fact.kind == FinancialBehaviorFactKind.unresolved) {
        unresolvedCount++;
      }

      if (fact.operationType != OperationType.expense) {
        continue;
      }

      legacyExpenseTotal += fact.amount;

      if (fact.requiresTransactionContext) {
        contextRequiredTotal += fact.amount;
      }

      switch (fact.kind) {
        case FinancialBehaviorFactKind.ordinarySpending:
          ordinarySpendingTotal += fact.amount;
        case FinancialBehaviorFactKind.assetBuilding:
          assetBuildingTotal += fact.amount;
        case FinancialBehaviorFactKind.debtReduction:
          debtReductionTotal += fact.amount;
        case FinancialBehaviorFactKind.cashMovement:
          cashMovementTotal += fact.amount;
        case FinancialBehaviorFactKind.dataAdjustment:
          dataAdjustmentTotal += fact.amount;
        case FinancialBehaviorFactKind.income ||
            FinancialBehaviorFactKind.unresolved:
          break;
      }
    }

    return FinancialBehaviorTotals(
      legacyExpenseTotal: legacyExpenseTotal,
      ordinarySpendingTotal: ordinarySpendingTotal,
      assetBuildingTotal: assetBuildingTotal,
      debtReductionTotal: debtReductionTotal,
      cashMovementTotal: cashMovementTotal,
      dataAdjustmentTotal: dataAdjustmentTotal,
      contextRequiredTotal: contextRequiredTotal,
      behavioralSavingsTotal: assetBuildingTotal,
      legacyVsIntelligenceDifference:
          legacyExpenseTotal - ordinarySpendingTotal,
      unresolvedCount: unresolvedCount,
    );
  }

  FinancialBehaviorCompatibilityOutput outputFor({
    required FinancialBehaviorFactsSnapshot snapshot,
    required FinancialModelPeriod period,
  }) {
    return FinancialBehaviorCompatibilityOutput(
      snapshot: snapshot,
      totals: totalsFor(snapshot: snapshot, period: period),
    );
  }
}

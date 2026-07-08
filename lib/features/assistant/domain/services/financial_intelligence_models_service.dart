import '../../../categories/domain/enums/category_financial_distribution_role.dart';
import '../entities/financial_behavior_compatibility_output.dart';
import '../entities/financial_behavior_fact_kind.dart';
import '../entities/financial_intelligence_model.dart';
import '../entities/financial_intelligence_model_type.dart';
import '../entities/financial_intelligence_models_snapshot.dart';
import '../entities/financial_model_period.dart';

final class FinancialIntelligenceModelsService {
  const FinancialIntelligenceModelsService();

  FinancialIntelligenceModelsSnapshot build({
    required FinancialBehaviorCompatibilityOutput output,
    required FinancialModelPeriod period,
    required double incomeTotal,
  }) {
    final mandatorySpendingTotal = _distributionTotal(
      output,
      period,
      CategoryFinancialDistributionRole.mandatoryExpenses,
    );
    final flexibleSpendingTotal = _distributionTotal(
      output,
      period,
      CategoryFinancialDistributionRole.flexibleExpenses,
    );
    final discretionarySpendingTotal = _distributionTotal(
      output,
      period,
      CategoryFinancialDistributionRole.wants,
    );
    final ordinarySpendingTotal = output.totals.ordinarySpendingTotal;

    return FinancialIntelligenceModelsSnapshot(
      models: [
        _money(
          FinancialIntelligenceModelType.ordinarySpendingTotal,
          ordinarySpendingTotal,
        ),
        _money(
          FinancialIntelligenceModelType.mandatorySpendingTotal,
          mandatorySpendingTotal,
        ),
        _money(
          FinancialIntelligenceModelType.flexibleSpendingTotal,
          flexibleSpendingTotal,
        ),
        _money(
          FinancialIntelligenceModelType.discretionarySpendingTotal,
          discretionarySpendingTotal,
        ),
        _money(
          FinancialIntelligenceModelType.assetBuildingTotal,
          output.totals.assetBuildingTotal,
        ),
        _money(
          FinancialIntelligenceModelType.debtReductionTotal,
          output.totals.debtReductionTotal,
        ),
        _money(
          FinancialIntelligenceModelType.cashMovementTotal,
          output.totals.cashMovementTotal,
        ),
        _money(
          FinancialIntelligenceModelType.dataAdjustmentTotal,
          output.totals.dataAdjustmentTotal,
        ),
        _money(
          FinancialIntelligenceModelType.contextRequiredTotal,
          output.totals.contextRequiredTotal,
        ),
        _money(
          FinancialIntelligenceModelType.behavioralSavingsTotal,
          output.totals.behavioralSavingsTotal,
        ),
        _ratio(
          FinancialIntelligenceModelType.ordinarySpendingRatio,
          ordinarySpendingTotal,
          incomeTotal,
        ),
        _ratio(
          FinancialIntelligenceModelType.mandatoryRatio,
          mandatorySpendingTotal,
          incomeTotal,
        ),
        _ratio(
          FinancialIntelligenceModelType.flexibleRatio,
          flexibleSpendingTotal,
          incomeTotal,
        ),
        _ratio(
          FinancialIntelligenceModelType.discretionaryRatio,
          discretionarySpendingTotal,
          incomeTotal,
        ),
      ],
    );
  }

  double _distributionTotal(
    FinancialBehaviorCompatibilityOutput output,
    FinancialModelPeriod period,
    CategoryFinancialDistributionRole role,
  ) {
    return output.snapshot.facts
        .where(
          (fact) =>
              period.contains(fact.occurredAt) &&
              fact.kind == FinancialBehaviorFactKind.ordinarySpending &&
              fact.distributionRole == role,
        )
        .fold<double>(0, (sum, fact) => sum + fact.amount);
  }

  FinancialIntelligenceModel _money(
    FinancialIntelligenceModelType type,
    double value,
  ) {
    return FinancialIntelligenceModel(type: type, value: value, isRatio: false);
  }

  FinancialIntelligenceModel _ratio(
    FinancialIntelligenceModelType type,
    double numerator,
    double denominator,
  ) {
    return FinancialIntelligenceModel(
      type: type,
      value: denominator <= 0 ? 0 : numerator / denominator,
      isRatio: true,
    );
  }
}

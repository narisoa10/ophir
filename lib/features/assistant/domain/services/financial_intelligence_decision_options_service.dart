import '../entities/financial_intelligence_decision_option.dart';
import '../entities/financial_intelligence_decision_option_type.dart';
import '../entities/financial_intelligence_decision_options_snapshot.dart';
import '../entities/financial_intelligence_model_parity_metric.dart';
import '../entities/financial_intelligence_model_parity_metric_result.dart';
import '../entities/financial_intelligence_model_parity_snapshot.dart';
import '../entities/financial_intelligence_problem.dart';
import '../entities/financial_intelligence_problem_type.dart';
import '../entities/financial_intelligence_problems_snapshot.dart';

final class FinancialIntelligenceDecisionOptionsService {
  const FinancialIntelligenceDecisionOptionsService();

  FinancialIntelligenceDecisionOptionsSnapshot build({
    required FinancialIntelligenceProblemsSnapshot problems,
    required FinancialIntelligenceModelParitySnapshot parity,
  }) {
    return FinancialIntelligenceDecisionOptionsSnapshot(
      options: [
        for (final problem in problems.problems) _optionFor(problem, parity),
      ],
    );
  }

  FinancialIntelligenceDecisionOption _optionFor(
    FinancialIntelligenceProblem problem,
    FinancialIntelligenceModelParitySnapshot parity,
  ) {
    final type = _typeFor(problem.type);
    final parityMetric = _parityMetricFor(problem.type);
    final parityResult = _parityResultFor(parityMetric, parity);

    return FinancialIntelligenceDecisionOption(
      optionId:
          'financial.intelligence.decisionOption.${type.name}.'
          '${problem.problemId}',
      type: type,
      period: problem.period,
      sourceProblemIds: [problem.problemId],
      sourceProblemTypes: [problem.type],
      parityMetric: parityMetric,
      parityStatus: parityResult?.status,
      legacyModelValue: parityResult?.legacyValue,
      intelligenceModelValue: parityResult?.intelligenceValue,
      isPositiveSignal: problem.isPositiveSignal,
      isWarning: problem.isWarning,
      isDiagnosticsOnly: true,
    );
  }

  FinancialIntelligenceDecisionOptionType _typeFor(
    FinancialIntelligenceProblemType type,
  ) {
    return switch (type) {
      FinancialIntelligenceProblemType.ordinarySpendingPressure =>
        FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure,
      FinancialIntelligenceProblemType.mandatoryCostPressure =>
        FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts,
      FinancialIntelligenceProblemType.reducibleSpendingPressure =>
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
      FinancialIntelligenceProblemType.discretionarySpendingPressure =>
        FinancialIntelligenceDecisionOptionType
            .deferOrReduceDiscretionarySpending,
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal =>
        FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum,
      FinancialIntelligenceProblemType.debtReductionSignal =>
        FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum,
      FinancialIntelligenceProblemType.transactionContextRequired =>
        FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
      FinancialIntelligenceProblemType.classificationCoverageGap =>
        FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
    };
  }

  FinancialIntelligenceModelParityMetric? _parityMetricFor(
    FinancialIntelligenceProblemType type,
  ) {
    return switch (type) {
      FinancialIntelligenceProblemType.ordinarySpendingPressure =>
        FinancialIntelligenceModelParityMetric.ordinarySpending,
      FinancialIntelligenceProblemType.mandatoryCostPressure =>
        FinancialIntelligenceModelParityMetric.mandatorySpending,
      FinancialIntelligenceProblemType.reducibleSpendingPressure =>
        FinancialIntelligenceModelParityMetric.reducibleSpending,
      FinancialIntelligenceProblemType.discretionarySpendingPressure =>
        FinancialIntelligenceModelParityMetric.discretionarySpending,
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal =>
        FinancialIntelligenceModelParityMetric.assetBuilding,
      FinancialIntelligenceProblemType.debtReductionSignal =>
        FinancialIntelligenceModelParityMetric.debtReduction,
      FinancialIntelligenceProblemType.transactionContextRequired ||
      FinancialIntelligenceProblemType.classificationCoverageGap => null,
    };
  }

  FinancialIntelligenceModelParityMetricResult? _parityResultFor(
    FinancialIntelligenceModelParityMetric? metric,
    FinancialIntelligenceModelParitySnapshot parity,
  ) {
    if (metric == null) {
      return null;
    }
    for (final result in parity.metricResults) {
      if (result.metric == metric) {
        return result;
      }
    }
    return null;
  }
}

import '../entities/financial_intelligence_problem.dart';
import '../entities/financial_intelligence_problem_type.dart';
import '../entities/financial_intelligence_problems_snapshot.dart';
import '../entities/financial_intelligence_recommendation.dart';
import '../entities/financial_intelligence_recommendation_diagnostics_snapshot.dart';
import '../entities/financial_intelligence_recommendation_type.dart';

final class FinancialIntelligenceRecommendationDiagnosticsService {
  const FinancialIntelligenceRecommendationDiagnosticsService();

  FinancialIntelligenceRecommendationDiagnosticsSnapshot build(
    FinancialIntelligenceProblemsSnapshot snapshot,
  ) {
    final recommendations = [
      for (final problem in snapshot.problems) _recommendationFor(problem),
    ];

    return FinancialIntelligenceRecommendationDiagnosticsSnapshot(
      recommendations: recommendations,
    );
  }

  FinancialIntelligenceRecommendation _recommendationFor(
    FinancialIntelligenceProblem problem,
  ) {
    final type = _typeFor(problem.type);

    return FinancialIntelligenceRecommendation(
      recommendationId:
          'financial.intelligence.recommendation.${type.name}.'
          '${problem.period.start.microsecondsSinceEpoch}.'
          '${problem.period.end.microsecondsSinceEpoch}',
      type: type,
      period: problem.period,
      sourceProblemIds: [problem.problemId],
      sourceProblemTypes: [problem.type],
      isPositiveSignal: problem.isPositiveSignal,
      isWarning: problem.isWarning,
      isDiagnosticsOnly: true,
    );
  }

  FinancialIntelligenceRecommendationType _typeFor(
    FinancialIntelligenceProblemType type,
  ) {
    return switch (type) {
      FinancialIntelligenceProblemType.ordinarySpendingPressure =>
        FinancialIntelligenceRecommendationType.reviewOrdinarySpendingStructure,
      FinancialIntelligenceProblemType.mandatoryCostPressure =>
        FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
      FinancialIntelligenceProblemType.reducibleSpendingPressure =>
        FinancialIntelligenceRecommendationType.reduceReducibleSpending,
      FinancialIntelligenceProblemType.discretionarySpendingPressure =>
        FinancialIntelligenceRecommendationType
            .deferOrReduceDiscretionarySpending,
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal =>
        FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum,
      FinancialIntelligenceProblemType.debtReductionSignal =>
        FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
      FinancialIntelligenceProblemType.transactionContextRequired =>
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
      FinancialIntelligenceProblemType.classificationCoverageGap =>
        FinancialIntelligenceRecommendationType.improveCategoryCoverage,
    };
  }
}

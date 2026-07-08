import '../entities/financial_deviation_severity.dart';
import '../entities/financial_intelligence_deviation.dart';
import '../entities/financial_intelligence_deviation_type.dart';
import '../entities/financial_intelligence_deviations_snapshot.dart';
import '../entities/financial_intelligence_problem.dart';
import '../entities/financial_intelligence_problem_type.dart';
import '../entities/financial_intelligence_problems_snapshot.dart';
import '../entities/financial_problem_impact.dart';
import '../entities/financial_problem_severity.dart';

final class FinancialIntelligenceProblemDetectionService {
  const FinancialIntelligenceProblemDetectionService();

  FinancialIntelligenceProblemsSnapshot detect(
    FinancialIntelligenceDeviationsSnapshot snapshot,
  ) {
    final problems = [
      for (final deviation in snapshot.deviations) _problemFor(deviation),
    ];

    return FinancialIntelligenceProblemsSnapshot(problems: problems);
  }

  FinancialIntelligenceProblem _problemFor(
    FinancialIntelligenceDeviation deviation,
  ) {
    final type = _typeFor(deviation.type);

    return FinancialIntelligenceProblem(
      problemId:
          'financial.intelligence.problem.${type.name}.'
          '${deviation.period.start.microsecondsSinceEpoch}.'
          '${deviation.period.end.microsecondsSinceEpoch}',
      type: type,
      period: deviation.period,
      severity: _severityFor(deviation.severity),
      impact: _impactFor(type),
      sourceDeviationIds: [deviation.deviationId],
      sourceDeviationTypes: [deviation.type],
      isPositiveSignal: _isPositiveSignal(type),
      isWarning: deviation.isWarning,
      isDiagnosticsOnly: true,
    );
  }

  FinancialIntelligenceProblemType _typeFor(
    FinancialIntelligenceDeviationType type,
  ) {
    return switch (type) {
      FinancialIntelligenceDeviationType.ordinarySpendingPressure =>
        FinancialIntelligenceProblemType.ordinarySpendingPressure,
      FinancialIntelligenceDeviationType.mandatorySpendingPressure =>
        FinancialIntelligenceProblemType.mandatoryCostPressure,
      FinancialIntelligenceDeviationType.flexibleSpendingPressure =>
        FinancialIntelligenceProblemType.reducibleSpendingPressure,
      FinancialIntelligenceDeviationType.discretionarySpendingPressure =>
        FinancialIntelligenceProblemType.discretionarySpendingPressure,
      FinancialIntelligenceDeviationType.assetBuildingSignal =>
        FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
      FinancialIntelligenceDeviationType.debtReductionSignal =>
        FinancialIntelligenceProblemType.debtReductionSignal,
      FinancialIntelligenceDeviationType.contextRequiredWarning =>
        FinancialIntelligenceProblemType.transactionContextRequired,
      FinancialIntelligenceDeviationType.unresolvedBehaviorWarning =>
        FinancialIntelligenceProblemType.classificationCoverageGap,
    };
  }

  FinancialProblemImpact _impactFor(FinancialIntelligenceProblemType type) {
    return switch (type) {
      FinancialIntelligenceProblemType.ordinarySpendingPressure ||
      FinancialIntelligenceProblemType.mandatoryCostPressure ||
      FinancialIntelligenceProblemType.reducibleSpendingPressure ||
      FinancialIntelligenceProblemType.discretionarySpendingPressure =>
        FinancialProblemImpact.spendingFlexibility,
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal =>
        FinancialProblemImpact.savingsCapacity,
      FinancialIntelligenceProblemType.debtReductionSignal =>
        FinancialProblemImpact.savingsCapacity,
      FinancialIntelligenceProblemType.transactionContextRequired ||
      FinancialIntelligenceProblemType.classificationCoverageGap =>
        FinancialProblemImpact.dataReliability,
    };
  }

  bool _isPositiveSignal(FinancialIntelligenceProblemType type) {
    return switch (type) {
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal ||
      FinancialIntelligenceProblemType.debtReductionSignal => true,
      _ => false,
    };
  }

  FinancialProblemSeverity _severityFor(FinancialDeviationSeverity severity) {
    return switch (severity) {
      FinancialDeviationSeverity.low => FinancialProblemSeverity.low,
      FinancialDeviationSeverity.medium => FinancialProblemSeverity.medium,
      FinancialDeviationSeverity.high => FinancialProblemSeverity.high,
    };
  }
}

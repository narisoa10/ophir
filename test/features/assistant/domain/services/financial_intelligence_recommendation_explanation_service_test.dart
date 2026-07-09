import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problems_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_recommendation_explanation_service.dart';

void main() {
  const service = FinancialIntelligenceRecommendationExplanationService();

  group('FinancialIntelligenceRecommendationExplanationService', () {
    test('creates explanation for every selected recommendation', () {
      for (final type in FinancialIntelligenceDecisionOptionType.values) {
        final problemType = _problemTypeForOption(type);
        final problem = _problem(problemType);
        final option = _option(type, problem: problem);

        final snapshot = service.build(
          selection: _selection(option),
          problems: FinancialIntelligenceProblemsSnapshot(problems: [problem]),
          parity: _paritySnapshot(),
        );
        final explanation = snapshot.explanation;

        expect(explanation.selectedRecommendation, same(option));
        expect(
          explanation.selectionReason,
          FinancialIntelligenceRecommendationSelectionReason.priorityOrder,
        );
        expect(explanation.isDiagnosticsOnly, isTrue);
      }
    });

    test('evidence contains supporting problems', () {
      final problem = _problem(
        FinancialIntelligenceProblemType.reducibleSpendingPressure,
        sourceDeviationIds: const ['deviation-1', 'deviation-2'],
        sourceDeviationTypes: const [
          FinancialIntelligenceDeviationType.flexibleSpendingPressure,
        ],
      );
      final option = _option(
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
        problem: problem,
        parityMetric: FinancialIntelligenceModelParityMetric.reducibleSpending,
      );

      final snapshot = service.build(
        selection: _selection(option),
        problems: FinancialIntelligenceProblemsSnapshot(problems: [problem]),
        parity: _paritySnapshot(),
      );
      final evidence = snapshot.explanation.evidence.single;

      expect(snapshot.explanation.supportingProblems, [problem]);
      expect(evidence.sourceProblemIds, [problem.problemId]);
      expect(evidence.sourceProblemTypes, [problem.type]);
      expect(evidence.sourceDeviationIds, ['deviation-1', 'deviation-2']);
      expect(evidence.sourceDeviationTypes, [
        FinancialIntelligenceDeviationType.flexibleSpendingPressure,
      ]);
    });

    test('parity metrics are included when available', () {
      final problem = _problem(
        FinancialIntelligenceProblemType.reducibleSpendingPressure,
      );
      final option = _option(
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
        problem: problem,
        parityMetric: FinancialIntelligenceModelParityMetric.reducibleSpending,
      );

      final snapshot = service.build(
        selection: _selection(option),
        problems: FinancialIntelligenceProblemsSnapshot(problems: [problem]),
        parity: _paritySnapshot(),
      );
      final explanation = snapshot.explanation;

      expect(
        explanation.supportingParityMetrics.single.metric,
        FinancialIntelligenceModelParityMetric.reducibleSpending,
      );
      expect(explanation.evidence.single.parityMetrics, [
        FinancialIntelligenceModelParityMetric.reducibleSpending,
      ]);
    });

    test('diagnostics-only flags are set', () {
      final problem = _problem(
        FinancialIntelligenceProblemType.transactionContextRequired,
      );
      final option = _option(
        FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
        problem: problem,
      );

      final snapshot = service.build(
        selection: _selection(option),
        problems: FinancialIntelligenceProblemsSnapshot(problems: [problem]),
        parity: _paritySnapshot(),
      );

      expect(snapshot.explanation.isDiagnosticsOnly, isTrue);
      expect(snapshot.explanation.evidence.single.isDiagnosticsOnly, isTrue);
      expect(snapshot.explanation.supportingParityMetrics, isEmpty);
    });

    test(
      'no selected recommendation returns empty diagnostics explanation',
      () {
        final snapshot = service.build(
          selection: FinancialIntelligenceRecommendationSelectionSnapshot(
            selection: FinancialIntelligenceRecommendationSelection(
              selectedOption: null,
              rejectedOptions: const [],
              selectionReason:
                  FinancialIntelligenceRecommendationSelectionReason
                      .noAvailableOptions,
              isDiagnosticsOnly: true,
            ),
          ),
          problems: FinancialIntelligenceProblemsSnapshot(problems: const []),
          parity: _paritySnapshot(),
        );

        expect(snapshot.explanation.selectedRecommendation, isNull);
        expect(snapshot.explanation.supportingProblems, isEmpty);
        expect(snapshot.explanation.supportingParityMetrics, isEmpty);
        expect(snapshot.explanation.evidence, isEmpty);
        expect(snapshot.explanation.isDiagnosticsOnly, isTrue);
      },
    );
  });
}

FinancialIntelligenceRecommendationSelectionSnapshot _selection(
  FinancialIntelligenceDecisionOption selected,
) {
  return FinancialIntelligenceRecommendationSelectionSnapshot(
    selection: FinancialIntelligenceRecommendationSelection(
      selectedOption: selected,
      rejectedOptions: const [],
      selectionReason:
          FinancialIntelligenceRecommendationSelectionReason.priorityOrder,
      isDiagnosticsOnly: true,
    ),
  );
}

FinancialIntelligenceDecisionOption _option(
  FinancialIntelligenceDecisionOptionType type, {
  required FinancialIntelligenceProblem problem,
  FinancialIntelligenceModelParityMetric? parityMetric,
}) {
  final isPositiveSignal =
      type ==
          FinancialIntelligenceDecisionOptionType
              .maintainAssetBuildingMomentum ||
      type ==
          FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum;

  return FinancialIntelligenceDecisionOption(
    optionId: 'financial.intelligence.decisionOption.${type.name}',
    type: type,
    period: problem.period,
    sourceProblemIds: [problem.problemId],
    sourceProblemTypes: [problem.type],
    parityMetric: parityMetric,
    parityStatus: null,
    legacyModelValue: null,
    intelligenceModelValue: null,
    isPositiveSignal: isPositiveSignal,
    isWarning: !isPositiveSignal,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceProblem _problem(
  FinancialIntelligenceProblemType type, {
  List<String> sourceDeviationIds = const ['source-deviation'],
  List<FinancialIntelligenceDeviationType> sourceDeviationTypes = const [],
}) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );
  final isPositiveSignal =
      type == FinancialIntelligenceProblemType.positiveAssetBuildingSignal ||
      type == FinancialIntelligenceProblemType.debtReductionSignal;

  return FinancialIntelligenceProblem(
    problemId: 'financial.intelligence.problem.${type.name}',
    type: type,
    period: period,
    severity: FinancialProblemSeverity.medium,
    impact: isPositiveSignal
        ? FinancialProblemImpact.savingsCapacity
        : FinancialProblemImpact.spendingFlexibility,
    sourceDeviationIds: sourceDeviationIds,
    sourceDeviationTypes: sourceDeviationTypes,
    isPositiveSignal: isPositiveSignal,
    isWarning: !isPositiveSignal,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceProblemType _problemTypeForOption(
  FinancialIntelligenceDecisionOptionType type,
) {
  return switch (type) {
    FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
      FinancialIntelligenceProblemType.ordinarySpendingPressure,
    FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts =>
      FinancialIntelligenceProblemType.mandatoryCostPressure,
    FinancialIntelligenceDecisionOptionType.reduceReducibleSpending =>
      FinancialIntelligenceProblemType.reducibleSpendingPressure,
    FinancialIntelligenceDecisionOptionType
        .deferOrReduceDiscretionarySpending =>
      FinancialIntelligenceProblemType.discretionarySpendingPressure,
    FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum =>
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
    FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
      FinancialIntelligenceProblemType.debtReductionSignal,
    FinancialIntelligenceDecisionOptionType.reviewTransactionContext =>
      FinancialIntelligenceProblemType.transactionContextRequired,
    FinancialIntelligenceDecisionOptionType.improveCategoryCoverage =>
      FinancialIntelligenceProblemType.classificationCoverageGap,
  };
}

FinancialIntelligenceModelParitySnapshot _paritySnapshot() {
  final result = FinancialIntelligenceModelParityMetricResult(
    metric: FinancialIntelligenceModelParityMetric.reducibleSpending,
    status: FinancialIntelligenceModelParityStatus.equivalent,
    legacyValue: 300,
    intelligenceValue: 300,
  );

  return FinancialIntelligenceModelParitySnapshot(
    legacyModelValues: {result.metric: result.legacyValue},
    intelligenceModelValues: {result.metric: result.intelligenceValue},
    metricResults: [result],
    matchedMetrics: [result],
    missingMetrics: const [],
    intentionallyDivergentMetrics: const [],
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problems_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_decision_options_service.dart';

void main() {
  const service = FinancialIntelligenceDecisionOptionsService();

  group('FinancialIntelligenceDecisionOptionsService', () {
    test('maps every intelligence problem to expected decision option', () {
      final snapshot = service.build(
        problems: FinancialIntelligenceProblemsSnapshot(
          problems: [
            for (final type in FinancialIntelligenceProblemType.values)
              _problem(type),
          ],
        ),
        parity: _paritySnapshot(),
      );

      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType
              .reviewOrdinarySpendingStructure,
        ),
        isTrue,
      );
      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts,
        ),
        isTrue,
      );
      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
        ),
        isTrue,
      );
      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType
              .deferOrReduceDiscretionarySpending,
        ),
        isTrue,
      );
      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum,
        ),
        isTrue,
      );
      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum,
        ),
        isTrue,
      );
      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
        ),
        isTrue,
      );
      expect(
        snapshot.hasOption(
          FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
        ),
        isTrue,
      );
    });

    test('parity context is attached to mapped model-backed options', () {
      final snapshot = service.build(
        problems: FinancialIntelligenceProblemsSnapshot(
          problems: [
            _problem(
              FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
            ),
          ],
        ),
        parity: _paritySnapshot(assetBuildingIntelligenceValue: 300),
      );
      final option = snapshot
          .optionsFor(
            FinancialIntelligenceDecisionOptionType
                .maintainAssetBuildingMomentum,
          )
          .single;

      expect(
        option.parityMetric,
        FinancialIntelligenceModelParityMetric.assetBuilding,
      );
      expect(
        option.parityStatus,
        FinancialIntelligenceModelParityStatus.unsupported,
      );
      expect(option.legacyModelValue, isNull);
      expect(option.intelligenceModelValue, 300);
    });

    test('context and coverage options remain diagnostics-only', () {
      final snapshot = service.build(
        problems: FinancialIntelligenceProblemsSnapshot(
          problems: [
            _problem(
              FinancialIntelligenceProblemType.transactionContextRequired,
            ),
            _problem(
              FinancialIntelligenceProblemType.classificationCoverageGap,
            ),
          ],
        ),
        parity: _paritySnapshot(),
      );

      for (final option in snapshot.options) {
        expect(option.isDiagnosticsOnly, isTrue);
        expect(option.isWarning, isTrue);
        expect(option.parityMetric, isNull);
        expect(option.parityStatus, isNull);
      }
    });
  });
}

FinancialIntelligenceProblem _problem(FinancialIntelligenceProblemType type) {
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
    sourceDeviationIds: const ['source-deviation'],
    sourceDeviationTypes: const [],
    isPositiveSignal: isPositiveSignal,
    isWarning: !isPositiveSignal,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceModelParitySnapshot _paritySnapshot({
  double assetBuildingIntelligenceValue = 0,
}) {
  final metricResults = [
    _parityResult(
      FinancialIntelligenceModelParityMetric.income,
      FinancialIntelligenceModelParityStatus.equal,
      legacyValue: 5000,
      intelligenceValue: 5000,
    ),
    _parityResult(
      FinancialIntelligenceModelParityMetric.ordinarySpending,
      FinancialIntelligenceModelParityStatus.equal,
      legacyValue: 1200,
      intelligenceValue: 1200,
    ),
    _parityResult(
      FinancialIntelligenceModelParityMetric.mandatorySpending,
      FinancialIntelligenceModelParityStatus.equivalent,
      legacyValue: 800,
      intelligenceValue: 800,
    ),
    _parityResult(
      FinancialIntelligenceModelParityMetric.reducibleSpending,
      FinancialIntelligenceModelParityStatus.equivalent,
      legacyValue: 300,
      intelligenceValue: 300,
    ),
    _parityResult(
      FinancialIntelligenceModelParityMetric.discretionarySpending,
      FinancialIntelligenceModelParityStatus.equivalent,
      legacyValue: 100,
      intelligenceValue: 100,
    ),
    _parityResult(
      FinancialIntelligenceModelParityMetric.assetBuilding,
      FinancialIntelligenceModelParityStatus.unsupported,
      legacyValue: null,
      intelligenceValue: assetBuildingIntelligenceValue,
    ),
    _parityResult(
      FinancialIntelligenceModelParityMetric.debtReduction,
      FinancialIntelligenceModelParityStatus.unsupported,
      legacyValue: null,
      intelligenceValue: 200,
    ),
  ];

  return FinancialIntelligenceModelParitySnapshot(
    legacyModelValues: {
      for (final result in metricResults) result.metric: result.legacyValue,
    },
    intelligenceModelValues: {
      for (final result in metricResults)
        result.metric: result.intelligenceValue,
    },
    metricResults: metricResults,
    matchedMetrics: metricResults
        .where(
          (result) =>
              result.status == FinancialIntelligenceModelParityStatus.equal ||
              result.status ==
                  FinancialIntelligenceModelParityStatus.equivalent,
        )
        .toList(growable: false),
    missingMetrics: metricResults
        .where(
          (result) =>
              result.status ==
              FinancialIntelligenceModelParityStatus.unsupported,
        )
        .toList(growable: false),
    intentionallyDivergentMetrics: const [],
  );
}

FinancialIntelligenceModelParityMetricResult _parityResult(
  FinancialIntelligenceModelParityMetric metric,
  FinancialIntelligenceModelParityStatus status, {
  required double? legacyValue,
  required double? intelligenceValue,
}) {
  return FinancialIntelligenceModelParityMetricResult(
    metric: metric,
    status: status,
    legacyValue: legacyValue,
    intelligenceValue: intelligenceValue,
  );
}

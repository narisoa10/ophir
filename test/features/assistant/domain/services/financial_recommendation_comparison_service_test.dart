import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_expected_model_change.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_objective.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_applicability.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_availability_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_condition.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_cost.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_cost_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_effect_horizon.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_risk.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_risk_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_target.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_target_direction.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_diagnostics_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_flag.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_conflict_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_evaluation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_priority.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_reversibility.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_status.dart';
import 'package:ophir/features/assistant/domain/services/financial_recommendation_comparison_service.dart';

void main() {
  const service = FinancialRecommendationComparisonService();

  group('FinancialRecommendationComparisonService', () {
    test('legacy recommendation present and no shadow diagnostics is legacyOnly', () {
      final comparison = service.build(
        legacyRecommendation: _legacyRecommendation(
          FinancialDecisionOptionType.reduceDiscretionarySpending,
        ),
        shadowDiagnostics: _shadowSnapshot(null),
      );

      expect(
        comparison.conflictLevel,
        FinancialRecommendationConflictLevel.legacyOnly,
      );
      expect(comparison.hasShadowDiagnostics, isFalse);
    });

    test('no legacy recommendation and shadow diagnostics is shadowOnly', () {
      final comparison = service.build(
        legacyRecommendation: null,
        shadowDiagnostics: _shadowSnapshot(
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
        ),
      );

      expect(
        comparison.conflictLevel,
        FinancialRecommendationConflictLevel.shadowOnly,
      );
      expect(comparison.hasShadowDiagnostics, isTrue);
    });

    test('matching legacy and shadow types is aligned', () {
      final comparison = service.build(
        legacyRecommendation: _legacyRecommendation(
          FinancialDecisionOptionType.reduceDiscretionarySpending,
        ),
        shadowDiagnostics: _shadowSnapshot(
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
        ),
      );

      expect(
        comparison.conflictLevel,
        FinancialRecommendationConflictLevel.aligned,
      );
      expect(
        comparison.flags,
        contains(FinancialRecommendationComparisonFlag.directMatch),
      );
    });

    test('partial match is partialOverlap', () {
      final comparison = service.build(
        legacyRecommendation: _legacyRecommendation(
          FinancialDecisionOptionType.buildSavingsCapacity,
        ),
        shadowDiagnostics: _shadowSnapshot(
          FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum,
          isPositiveSignal: true,
          isWarning: false,
        ),
      );

      expect(
        comparison.conflictLevel,
        FinancialRecommendationConflictLevel.partialOverlap,
      );
      expect(
        comparison.flags,
        contains(FinancialRecommendationComparisonFlag.partialMatch),
      );
    });

    test('unmatched comparable recommendation is divergent', () {
      final comparison = service.build(
        legacyRecommendation: _legacyRecommendation(
          FinancialDecisionOptionType.reduceDiscretionarySpending,
        ),
        shadowDiagnostics: _shadowSnapshot(
          FinancialIntelligenceRecommendationType.reviewTransactionContext,
        ),
      );

      expect(
        comparison.conflictLevel,
        FinancialRecommendationConflictLevel.divergent,
      );
      expect(
        comparison.flags,
        contains(FinancialRecommendationComparisonFlag.divergentMatch),
      );
    });

    test('not comparable legacy recommendation stays notComparable', () {
      final comparison = service.build(
        legacyRecommendation: _legacyRecommendation(
          FinancialDecisionOptionType.increaseIncome,
        ),
        shadowDiagnostics: _shadowSnapshot(
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
        ),
      );

      expect(
        comparison.conflictLevel,
        FinancialRecommendationConflictLevel.notComparable,
      );
      expect(
        comparison.flags,
        contains(FinancialRecommendationComparisonFlag.notComparable),
      );
    });

    test('positive context and coverage diagnostics set flags', () {
      final comparison = service.build(
        legacyRecommendation: null,
        shadowDiagnostics: FinancialIntelligenceRecommendationDiagnosticsSnapshot(
          recommendations: [
            _shadowRecommendation(
              FinancialIntelligenceRecommendationType
                  .maintainAssetBuildingMomentum,
              isPositiveSignal: true,
              isWarning: false,
            ),
            _shadowRecommendation(
              FinancialIntelligenceRecommendationType.reviewTransactionContext,
            ),
            _shadowRecommendation(
              FinancialIntelligenceRecommendationType.improveCategoryCoverage,
            ),
          ],
        ),
      );

      expect(comparison.hasPositiveSignals, isTrue);
      expect(comparison.hasContextWarnings, isTrue);
      expect(comparison.hasCoverageWarnings, isTrue);
      expect(
        comparison.flags,
        containsAll([
          FinancialRecommendationComparisonFlag.positiveSignalPresent,
          FinancialRecommendationComparisonFlag.contextWarningPresent,
          FinancialRecommendationComparisonFlag.coverageWarningPresent,
        ]),
      );
    });

    test('fixture parity matrix matches official policy', () {
      final cases = [
        _parityCase(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowType:
              FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowType: FinancialIntelligenceRecommendationType
              .deferOrReduceDiscretionarySpending,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.deferOptionalSpending,
          shadowType: FinancialIntelligenceRecommendationType
              .deferOrReduceDiscretionarySpending,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.optimizeEssentialExpenses,
          shadowType:
              FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.reviewExpenseStructure,
          shadowType: FinancialIntelligenceRecommendationType
              .reviewOrdinarySpendingStructure,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.reviewExpenseStructure,
          shadowType:
              FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.reviewExpenseStructure,
          shadowType:
              FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.improveCategorization,
          shadowType:
              FinancialIntelligenceRecommendationType.improveCategoryCoverage,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.collectMoreData,
          shadowType:
              FinancialIntelligenceRecommendationType.improveCategoryCoverage,
          expectedLevel: FinancialRecommendationConflictLevel.aligned,
          expectedFlag: FinancialRecommendationComparisonFlag.directMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.buildSavingsCapacity,
          shadowType: FinancialIntelligenceRecommendationType
              .maintainAssetBuildingMomentum,
          expectedLevel: FinancialRecommendationConflictLevel.partialOverlap,
          expectedFlag: FinancialRecommendationComparisonFlag.partialMatch,
          isPositiveSignal: true,
          isWarning: false,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.confirmRecurringOperations,
          shadowType:
              FinancialIntelligenceRecommendationType.reviewTransactionContext,
          expectedLevel: FinancialRecommendationConflictLevel.partialOverlap,
          expectedFlag: FinancialRecommendationComparisonFlag.partialMatch,
        ),
        _parityCase(
          legacyType: FinancialDecisionOptionType.reviewLargeExpense,
          shadowType:
              FinancialIntelligenceRecommendationType.reviewTransactionContext,
          expectedLevel: FinancialRecommendationConflictLevel.partialOverlap,
          expectedFlag: FinancialRecommendationComparisonFlag.partialMatch,
        ),
        for (final legacyType in [
          FinancialDecisionOptionType.increaseIncome,
          FinancialDecisionOptionType.useExistingReserves,
          FinancialDecisionOptionType.restructureObligations,
          FinancialDecisionOptionType.reviseFinancialStrategy,
          FinancialDecisionOptionType.adjustBudgetUnavailable,
          FinancialDecisionOptionType.doNothingAndMonitor,
        ])
          _parityCase(
            legacyType: legacyType,
            shadowType:
                FinancialIntelligenceRecommendationType.reduceReducibleSpending,
            expectedLevel: FinancialRecommendationConflictLevel.notComparable,
            expectedFlag: FinancialRecommendationComparisonFlag.notComparable,
          ),
      ];

      for (final fixture in cases) {
        final comparison = service.build(
          legacyRecommendation: _legacyRecommendation(fixture.legacyType),
          shadowDiagnostics: _shadowSnapshot(
            fixture.shadowType,
            isPositiveSignal: fixture.isPositiveSignal,
            isWarning: fixture.isWarning,
          ),
        );

        expect(
          comparison.conflictLevel,
          fixture.expectedLevel,
          reason: fixture.legacyType.name,
        );
        expect(
          comparison.flags,
          contains(fixture.expectedFlag),
          reason: fixture.legacyType.name,
        );
      }
    });
  });
}

_ParityCase _parityCase({
  required FinancialDecisionOptionType legacyType,
  required FinancialIntelligenceRecommendationType shadowType,
  required FinancialRecommendationConflictLevel expectedLevel,
  required FinancialRecommendationComparisonFlag expectedFlag,
  bool isPositiveSignal = false,
  bool isWarning = true,
}) {
  return _ParityCase(
    legacyType: legacyType,
    shadowType: shadowType,
    expectedLevel: expectedLevel,
    expectedFlag: expectedFlag,
    isPositiveSignal: isPositiveSignal,
    isWarning: isWarning,
  );
}

final class _ParityCase {
  const _ParityCase({
    required this.legacyType,
    required this.shadowType,
    required this.expectedLevel,
    required this.expectedFlag,
    required this.isPositiveSignal,
    required this.isWarning,
  });

  final FinancialDecisionOptionType legacyType;
  final FinancialIntelligenceRecommendationType shadowType;
  final FinancialRecommendationConflictLevel expectedLevel;
  final FinancialRecommendationComparisonFlag expectedFlag;
  final bool isPositiveSignal;
  final bool isWarning;
}

FinancialIntelligenceRecommendationDiagnosticsSnapshot _shadowSnapshot(
  FinancialIntelligenceRecommendationType? type, {
  bool isPositiveSignal = false,
  bool isWarning = true,
}) {
  return FinancialIntelligenceRecommendationDiagnosticsSnapshot(
    recommendations: [
      if (type != null)
        _shadowRecommendation(
          type,
          isPositiveSignal: isPositiveSignal,
          isWarning: isWarning,
        ),
    ],
  );
}

FinancialIntelligenceRecommendation _shadowRecommendation(
  FinancialIntelligenceRecommendationType type, {
  bool isPositiveSignal = false,
  bool isWarning = true,
}) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );

  return FinancialIntelligenceRecommendation(
    recommendationId: 'financial.intelligence.recommendation.${type.name}',
    type: type,
    period: period,
    sourceProblemIds: const ['problem'],
    sourceProblemTypes: const [
      FinancialIntelligenceProblemType.ordinarySpendingPressure,
    ],
    isPositiveSignal: isPositiveSignal,
    isWarning: isWarning,
    isDiagnosticsOnly: true,
  );
}

FinancialRecommendation _legacyRecommendation(
  FinancialDecisionOptionType type,
) {
  final option = _option(type);

  return FinancialRecommendation(
    recommendationId: 'financial.recommendation.${type.name}',
    selectedOption: option,
    selectedOptionId: option.optionId,
    selectedOptionType: type,
    status: FinancialRecommendationStatus.selected,
    priority: FinancialRecommendationPriority.medium,
    confidence: FinancialRecommendationConfidence.medium,
    evaluation: FinancialRecommendationEvaluation(
      optionId: option.optionId,
      optionType: type,
      expectedImpact: 1,
      cost: 1,
      risk: 1,
      applicability: 1,
      confidence: 1,
      urgency: 1,
      reversibility: FinancialRecommendationReversibility.high,
      horizon: 1,
      mayWorsenProblemCount: 0,
      factors: const [],
    ),
    rejectedAlternatives: const [],
    evidence: FinancialRecommendationEvidence(
      sourceOptionId: option.optionId,
      sourceProblemIds: const ['problem'],
      sourceProblemTypes: const ['expensePressure'],
      sourceDeviationIds: const ['deviation'],
      sourceModelIds: const ['model'],
    ),
    metadata: FinancialRecommendationMetadata(
      generatedAt: DateTime.utc(2035, 6),
      engineVersion: 'test',
    ),
  );
}

FinancialDecisionOption _option(FinancialDecisionOptionType type) {
  return FinancialDecisionOption(
    optionId: 'option.${type.name}',
    optionType: type,
    status: FinancialDecisionOptionStatus.available,
    applicability: FinancialDecisionOptionApplicability.applicable,
    linkedProblemIds: const ['problem'],
    solvesProblemTypes: const [FinancialProblemType.expensePressure],
    mayWorsenProblemTypes: const [],
    objectives: const <FinancialDecisionObjective>[],
    targets: const [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.expenseToIncomeRatio,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: const [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.expenseToIncomeRatio,
        direction: FinancialDecisionTargetDirection.decrease,
        expectedChange: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    impact: const FinancialDecisionOptionImpact(
      isQuantitative: false,
      effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
    ),
    cost: const FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: const FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.low,
      mayWorsenProblemTypes: [],
    ),
    conditions: const <FinancialDecisionOptionCondition>[],
    limitations: const <FinancialDecisionOptionLimitation>[],
    availabilityReasons: const <FinancialDecisionOptionAvailabilityReason>[],
    evidence: const FinancialDecisionOptionEvidence(
      sourceProblemIds: ['problem'],
      sourceProblemTypes: [FinancialProblemType.expensePressure],
      sourceDeviationIds: ['deviation'],
      sourceModelIds: ['model'],
    ),
    metadata: FinancialDecisionOptionMetadata(
      generatedAt: DateTime.utc(2035, 6),
      engineVersion: 'test',
      ruleId: 'rule.${type.name}',
    ),
    effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
  );
}

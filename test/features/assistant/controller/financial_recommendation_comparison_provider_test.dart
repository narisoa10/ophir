import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/current_assistant_recommendation_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_recommendation_diagnostics_provider.dart';
import 'package:ophir/features/assistant/controller/financial_recommendation_comparison_provider.dart';
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
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_conflict_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_evaluation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_priority.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_reversibility.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_status.dart';

void main() {
  group('financialRecommendationComparisonProvider', () {
    test('builds comparison read model from legacy and shadow providers', () async {
      final legacyRecommendation = _legacyRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final container = ProviderContainer(
        overrides: [
          currentAssistantRecommendationProvider.overrideWith(
            (ref) async => Success(legacyRecommendation),
          ),
          financialIntelligenceRecommendationDiagnosticsProvider.overrideWith(
            (ref) async => Success(
              _shadowSnapshot(
                FinancialIntelligenceRecommendationType
                    .reduceReducibleSpending,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialRecommendationComparisonProvider.future,
      );
      final comparison = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected recommendation comparison'),
      };

      expect(
        comparison.legacyRecommendationType,
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      expect(
        comparison.shadowRecommendationTypes,
        [
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
        ],
      );
      expect(
        comparison.conflictLevel,
        FinancialRecommendationConflictLevel.aligned,
      );
    });

    test('does not mutate current Assistant recommendation', () async {
      final legacyRecommendation = _legacyRecommendation(
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
      final container = ProviderContainer(
        overrides: [
          currentAssistantRecommendationProvider.overrideWith(
            (ref) async => Success(legacyRecommendation),
          ),
          financialIntelligenceRecommendationDiagnosticsProvider.overrideWith(
            (ref) async => Success(
              _shadowSnapshot(
                FinancialIntelligenceRecommendationType
                    .reviewOrdinarySpendingStructure,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final before = await container.read(
        currentAssistantRecommendationProvider.future,
      );
      await container.read(financialRecommendationComparisonProvider.future);
      final after = await container.read(
        currentAssistantRecommendationProvider.future,
      );
      final beforeRecommendation = switch (before) {
        Success(:final value) => value,
        Failure() => fail('Expected recommendation before comparison'),
      };
      final afterRecommendation = switch (after) {
        Success(:final value) => value,
        Failure() => fail('Expected recommendation after comparison'),
      };

      expect(
        afterRecommendation?.selectedOptionType,
        beforeRecommendation?.selectedOptionType,
      );
    });

    test('provider reads only current recommendation and shadow diagnostics', () {
      final source = File(
        'lib/features/assistant/controller/financial_recommendation_comparison_provider.dart',
      ).readAsStringSync();

      expect(source, contains('currentAssistantRecommendationProvider'));
      expect(
        source,
        contains('financialIntelligenceRecommendationDiagnosticsProvider'),
      );
      expect(source, isNot(contains('dashboard')));
      expect(source, isNot(contains('operationsProvider')));
      expect(source, isNot(contains('operationDisplayCategoriesProvider')));
      expect(source, isNot(contains('FinancialRecommendationService')));
      expect(source, isNot(contains('FinancialExplanationService')));
    });

    test('Dashboard and UI do not import comparison provider', () {
      final files = [
        ...Directory('lib/features/dashboard').listSync(recursive: true),
        ...Directory('lib/features/operations').listSync(recursive: true),
      ].whereType<File>();

      for (final file in files) {
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('financial_recommendation_comparison_provider')),
          reason: file.path,
        );
        expect(
          source,
          isNot(contains('FinancialRecommendationComparisonReadModel')),
          reason: file.path,
        );
      }
    });
  });
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

FinancialIntelligenceRecommendationDiagnosticsSnapshot _shadowSnapshot(
  FinancialIntelligenceRecommendationType type,
) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );

  return FinancialIntelligenceRecommendationDiagnosticsSnapshot(
    recommendations: [
      FinancialIntelligenceRecommendation(
        recommendationId: 'financial.intelligence.recommendation.${type.name}',
        type: type,
        period: period,
        sourceProblemIds: const ['problem'],
        sourceProblemTypes: const [
          FinancialIntelligenceProblemType.ordinarySpendingPressure,
        ],
        isPositiveSignal: false,
        isWarning: true,
        isDiagnosticsOnly: true,
      ),
    ],
  );
}

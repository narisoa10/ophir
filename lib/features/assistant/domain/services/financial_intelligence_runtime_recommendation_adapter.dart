import '../entities/financial_decision_expected_model_change.dart';
import '../entities/financial_decision_objective.dart';
import '../entities/financial_decision_objective_type.dart';
import '../entities/financial_decision_option.dart';
import '../entities/financial_decision_option_applicability.dart';
import '../entities/financial_decision_option_availability_reason.dart';
import '../entities/financial_decision_option_condition.dart';
import '../entities/financial_decision_option_cost.dart';
import '../entities/financial_decision_option_cost_level.dart';
import '../entities/financial_decision_option_effect_horizon.dart';
import '../entities/financial_decision_option_evidence.dart';
import '../entities/financial_decision_option_impact.dart';
import '../entities/financial_decision_option_limitation.dart';
import '../entities/financial_decision_option_metadata.dart';
import '../entities/financial_decision_option_risk.dart';
import '../entities/financial_decision_option_risk_level.dart';
import '../entities/financial_decision_option_status.dart';
import '../entities/financial_decision_option_type.dart';
import '../entities/financial_decision_target.dart';
import '../entities/financial_decision_target_direction.dart';
import '../entities/financial_intelligence_decision_option.dart';
import '../entities/financial_intelligence_decision_option_type.dart';
import '../entities/financial_intelligence_model_parity_status.dart';
import '../entities/financial_intelligence_problem_type.dart';
import '../entities/financial_intelligence_recommendation_explanation_snapshot.dart';
import '../entities/financial_intelligence_recommendation_selection_snapshot.dart';
import '../entities/financial_intelligence_recommendation_type.dart';
import '../entities/financial_intelligence_runtime_recommendation_candidate.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_model_unit.dart';
import '../entities/financial_problem_confidence.dart';
import '../entities/financial_problem_type.dart';
import '../entities/financial_recommendation.dart';
import '../entities/financial_recommendation_comparison_read_model.dart';
import '../entities/financial_recommendation_confidence.dart';
import '../entities/financial_recommendation_conflict_level.dart';
import '../entities/financial_recommendation_evaluation.dart';
import '../entities/financial_recommendation_evaluation_factor.dart';
import '../entities/financial_recommendation_evidence.dart';
import '../entities/financial_recommendation_factor_direction.dart';
import '../entities/financial_recommendation_factor_type.dart';
import '../entities/financial_recommendation_metadata.dart';
import '../entities/financial_recommendation_priority.dart';
import '../entities/financial_recommendation_reversibility.dart';
import '../entities/financial_recommendation_status.dart';
import '../entities/financial_rejected_alternative.dart';
import '../entities/financial_rejected_alternative_reason.dart';
import 'financial_intelligence_runtime_explanation_adapter.dart';

final class FinancialIntelligenceRuntimeRecommendationAdapter {
  const FinancialIntelligenceRuntimeRecommendationAdapter({
    FinancialIntelligenceRuntimeExplanationAdapter explanationAdapter =
        const FinancialIntelligenceRuntimeExplanationAdapter(),
  }) : _explanationAdapter = explanationAdapter;

  final FinancialIntelligenceRuntimeExplanationAdapter _explanationAdapter;

  FinancialIntelligenceRuntimeRecommendationCandidate build({
    required FinancialIntelligenceRecommendationSelectionSnapshot selection,
    required FinancialIntelligenceRecommendationExplanationSnapshot explanation,
    required FinancialRecommendationComparisonReadModel comparison,
    DateTime? generatedAt,
  }) {
    final selected = selection.selectedOption;
    final rejectedIds = [
      for (final option in selection.rejectedOptions) option.optionId,
    ];
    final isDiagnosticsOnlySource =
        selection.isDiagnosticsOnly &&
        explanation.explanation.isDiagnosticsOnly &&
        (selected?.isDiagnosticsOnly ?? true) &&
        (explanation.explanation.selectedRecommendation?.isDiagnosticsOnly ??
            true);

    if (selected == null) {
      return _blocked(
        sourceIds: const [],
        rejectedIds: rejectedIds,
        isDiagnosticsOnlySource: isDiagnosticsOnlySource,
        reasons: const ['missingSelectedOption'],
      );
    }
    if (!isDiagnosticsOnlySource) {
      return _blocked(
        sourceIds: [selected.optionId],
        rejectedIds: rejectedIds,
        isDiagnosticsOnlySource: isDiagnosticsOnlySource,
        reasons: const ['sourceNotDiagnosticsOnly'],
      );
    }

    final runtimeType = _runtimeTypeFor(selected.type);
    final comparisonType = _comparisonTypeFor(selected.type);
    if (runtimeType == null || comparisonType == null) {
      return _blocked(
        sourceIds: [selected.optionId],
        rejectedIds: rejectedIds,
        isDiagnosticsOnlySource: isDiagnosticsOnlySource,
        reasons: const ['unsupportedIntelligenceOption'],
      );
    }
    if (comparison.conflictLevel !=
        FinancialRecommendationConflictLevel.aligned) {
      return _blocked(
        sourceIds: [selected.optionId],
        rejectedIds: rejectedIds,
        isDiagnosticsOnlySource: isDiagnosticsOnlySource,
        reasons: const ['comparisonNotAligned'],
      );
    }
    if (comparison.legacyRecommendationType != runtimeType) {
      return _blocked(
        sourceIds: [selected.optionId],
        rejectedIds: rejectedIds,
        isDiagnosticsOnlySource: isDiagnosticsOnlySource,
        reasons: const ['comparisonLegacyTypeMismatch'],
      );
    }
    if (!comparison.shadowRecommendationTypes.contains(comparisonType)) {
      return _blocked(
        sourceIds: [selected.optionId],
        rejectedIds: rejectedIds,
        isDiagnosticsOnlySource: isDiagnosticsOnlySource,
        reasons: const ['comparisonMissingSelectedIntelligenceType'],
      );
    }

    final timestamp = generatedAt ?? DateTime.now().toUtc();
    final confidence = _confidenceFor(selected);
    final priority = _priorityFor(selected);
    final option = _decisionOptionFor(
      selected: selected,
      runtimeType: runtimeType,
      generatedAt: timestamp,
    );
    final recommendation = _recommendationFor(
      selected: selected,
      option: option,
      confidence: confidence,
      priority: priority,
      generatedAt: timestamp,
      rejectedOptions: selection.rejectedOptions,
    );
    final adaptedExplanation = _explanationAdapter.adapt(
      recommendation: recommendation,
      selection: selection,
      explanation: explanation,
      generatedAt: timestamp,
    );
    if (adaptedExplanation == null) {
      return _blocked(
        sourceIds: [selected.optionId],
        rejectedIds: rejectedIds,
        isDiagnosticsOnlySource: isDiagnosticsOnlySource,
        reasons: const ['invalidExplanation'],
        confidence: confidence,
        priority: priority,
      );
    }

    return FinancialIntelligenceRuntimeRecommendationCandidate(
      adaptedRecommendation: recommendation,
      adaptedExplanation: adaptedExplanation,
      sourceIntelligenceOptionIds: [selected.optionId],
      rejectedIntelligenceOptionIds: rejectedIds,
      isEligibleForRuntime: true,
      blockReasons: const [],
      confidence: confidence,
      priority: priority,
      isDiagnosticsOnlySource: true,
    );
  }

  FinancialIntelligenceRuntimeRecommendationCandidate _blocked({
    required List<String> sourceIds,
    required List<String> rejectedIds,
    required bool isDiagnosticsOnlySource,
    required List<String> reasons,
    FinancialRecommendationConfidence confidence =
        FinancialRecommendationConfidence.none,
    FinancialRecommendationPriority priority =
        FinancialRecommendationPriority.low,
  }) {
    return FinancialIntelligenceRuntimeRecommendationCandidate(
      adaptedRecommendation: null,
      adaptedExplanation: null,
      sourceIntelligenceOptionIds: sourceIds,
      rejectedIntelligenceOptionIds: rejectedIds,
      isEligibleForRuntime: false,
      blockReasons: reasons,
      confidence: confidence,
      priority: priority,
      isDiagnosticsOnlySource: isDiagnosticsOnlySource,
    );
  }

  FinancialDecisionOption _decisionOptionFor({
    required FinancialIntelligenceDecisionOption selected,
    required FinancialDecisionOptionType runtimeType,
    required DateTime generatedAt,
  }) {
    final problemTypes = _legacyProblemTypesFor(selected);
    final sourceProblemId = selected.sourceProblemIds.isEmpty
        ? selected.optionId
        : selected.sourceProblemIds.first;
    final primaryProblemType = problemTypes.isEmpty
        ? FinancialProblemType.expensePressure
        : problemTypes.first;
    final target = _targetFor(runtimeType);

    return FinancialDecisionOption(
      optionId: _runtimeOptionId(selected.optionId),
      optionType: runtimeType,
      status: FinancialDecisionOptionStatus.available,
      applicability: FinancialDecisionOptionApplicability.applicable,
      linkedProblemIds: selected.sourceProblemIds,
      solvesProblemTypes: problemTypes,
      mayWorsenProblemTypes: const [],
      objectives: [
        FinancialDecisionObjective(
          objectiveId:
              'financial.intelligence.runtime.objective.${selected.optionId}',
          objectiveType: _objectiveTypeFor(runtimeType),
          sourceProblemId: sourceProblemId,
          sourceProblemType: primaryProblemType,
        ),
      ],
      targets: [target],
      expectedModelChanges: [
        FinancialDecisionExpectedModelChange(
          modelType: target.targetModelType,
          direction: target.desiredDirection,
          expectedChange: null,
          unit: target.unit,
          confidence: target.confidence,
        ),
      ],
      impact: FinancialDecisionOptionImpact(
        isQuantitative: false,
        effectHorizon: _effectHorizonFor(runtimeType),
      ),
      cost: _costFor(runtimeType),
      risk: const FinancialDecisionOptionRisk(
        level: FinancialDecisionOptionRiskLevel.low,
        mayWorsenProblemTypes: [],
      ),
      conditions: const <FinancialDecisionOptionCondition>[],
      limitations: const [
        FinancialDecisionOptionLimitation(
          limitationId: 'financialIntelligenceRuntimeAdapterV1',
        ),
      ],
      availabilityReasons: const [
        FinancialDecisionOptionAvailabilityReason(
          reasonId: 'financialIntelligenceAllowlist',
        ),
      ],
      evidence: FinancialDecisionOptionEvidence(
        sourceProblemIds: selected.sourceProblemIds,
        sourceProblemTypes: problemTypes,
        sourceDeviationIds: const [],
        sourceModelIds: _modelIdsFor(selected),
      ),
      metadata: FinancialDecisionOptionMetadata(
        generatedAt: generatedAt,
        engineVersion: 'financial-intelligence-runtime-adapter-v1',
        ruleId: 'financial.intelligence.runtime.rule.${selected.type.name}',
      ),
      effectHorizon: _effectHorizonFor(runtimeType),
    );
  }

  FinancialRecommendation _recommendationFor({
    required FinancialIntelligenceDecisionOption selected,
    required FinancialDecisionOption option,
    required FinancialRecommendationConfidence confidence,
    required FinancialRecommendationPriority priority,
    required DateTime generatedAt,
    required List<FinancialIntelligenceDecisionOption> rejectedOptions,
  }) {
    return FinancialRecommendation(
      recommendationId:
          'financial.intelligence.runtime.recommendation.${selected.optionId}',
      selectedOption: option,
      selectedOptionId: option.optionId,
      selectedOptionType: option.optionType,
      status: FinancialRecommendationStatus.selected,
      priority: priority,
      confidence: confidence,
      evaluation: _evaluationFor(option: option, confidence: confidence),
      rejectedAlternatives: [
        for (final rejected in rejectedOptions)
          if (_runtimeTypeFor(rejected.type) case final type?)
            FinancialRejectedAlternative(
              optionId: _runtimeOptionId(rejected.optionId),
              optionType: type,
              reasonCodes: const [
                FinancialRejectedAlternativeReason.deterministicTieBreak,
              ],
              evidence: FinancialRecommendationEvidence(
                sourceOptionId: _runtimeOptionId(rejected.optionId),
                sourceProblemIds: rejected.sourceProblemIds,
                sourceProblemTypes: [
                  for (final problemType in _legacyProblemTypesFor(rejected))
                    problemType.name,
                ],
                sourceDeviationIds: const [],
                sourceModelIds: _modelIdsFor(rejected),
              ),
            ),
      ],
      evidence: FinancialRecommendationEvidence(
        sourceOptionId: option.optionId,
        sourceProblemIds: selected.sourceProblemIds,
        sourceProblemTypes: [
          for (final problemType in _legacyProblemTypesFor(selected))
            problemType.name,
        ],
        sourceDeviationIds: const [],
        sourceModelIds: _modelIdsFor(selected),
      ),
      metadata: FinancialRecommendationMetadata(
        generatedAt: generatedAt,
        engineVersion: 'financial-intelligence-runtime-adapter-v1',
      ),
    );
  }

  FinancialRecommendationEvaluation _evaluationFor({
    required FinancialDecisionOption option,
    required FinancialRecommendationConfidence confidence,
  }) {
    final confidenceValue = switch (confidence) {
      FinancialRecommendationConfidence.none => 0,
      FinancialRecommendationConfidence.low => 1,
      FinancialRecommendationConfidence.medium => 2,
      FinancialRecommendationConfidence.high => 3,
    };

    return FinancialRecommendationEvaluation(
      optionId: option.optionId,
      optionType: option.optionType,
      expectedImpact: 2,
      cost: 1,
      risk: 1,
      applicability: 3,
      confidence: confidenceValue,
      urgency: 2,
      reversibility: FinancialRecommendationReversibility.high,
      horizon: 2,
      mayWorsenProblemCount: 0,
      factors: [
        const FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.applicability,
          direction: FinancialRecommendationFactorDirection.positive,
          value: 3,
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.confidence,
          direction: FinancialRecommendationFactorDirection.positive,
          value: confidenceValue,
        ),
      ],
    );
  }

  FinancialDecisionTarget _targetFor(FinancialDecisionOptionType type) {
    return switch (type) {
      FinancialDecisionOptionType.reviewExpenseStructure =>
        const FinancialDecisionTarget(
          targetModelType: FinancialModelType.expenseAnalyticsGroupTotals,
          desiredDirection: FinancialDecisionTargetDirection.clarify,
          expectedImprovement: null,
          unit: FinancialModelUnit.money,
          confidence: FinancialProblemConfidence.medium,
        ),
      FinancialDecisionOptionType.improveCategorization =>
        const FinancialDecisionTarget(
          targetModelType: FinancialModelType.dataQualityScore,
          desiredDirection: FinancialDecisionTargetDirection.increase,
          expectedImprovement: null,
          unit: FinancialModelUnit.score,
          confidence: FinancialProblemConfidence.medium,
        ),
      _ => const FinancialDecisionTarget(
        targetModelType: FinancialModelType.expenseToIncomeRatio,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
    };
  }

  FinancialDecisionObjectiveType _objectiveTypeFor(
    FinancialDecisionOptionType type,
  ) {
    return switch (type) {
      FinancialDecisionOptionType.reduceDiscretionarySpending ||
      FinancialDecisionOptionType.deferOptionalSpending =>
        FinancialDecisionObjectiveType.reduceDiscretionaryPressure,
      FinancialDecisionOptionType.improveCategorization =>
        FinancialDecisionObjectiveType.improveDataReliability,
      _ => FinancialDecisionObjectiveType.reduceExpensePressure,
    };
  }

  FinancialDecisionOptionCost _costFor(FinancialDecisionOptionType type) {
    final effort = switch (type) {
      FinancialDecisionOptionType.reduceDiscretionarySpending =>
        FinancialDecisionOptionCostLevel.medium,
      _ => FinancialDecisionOptionCostLevel.low,
    };

    return FinancialDecisionOptionCost(
      effort: effort,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    );
  }

  FinancialDecisionOptionEffectHorizon _effectHorizonFor(
    FinancialDecisionOptionType type,
  ) {
    return switch (type) {
      FinancialDecisionOptionType.deferOptionalSpending =>
        FinancialDecisionOptionEffectHorizon.immediate,
      FinancialDecisionOptionType.improveCategorization =>
        FinancialDecisionOptionEffectHorizon.shortTerm,
      _ => FinancialDecisionOptionEffectHorizon.shortTerm,
    };
  }

  FinancialRecommendationConfidence _confidenceFor(
    FinancialIntelligenceDecisionOption selected,
  ) {
    return switch (selected.parityStatus) {
      FinancialIntelligenceModelParityStatus.intentionallyDifferent ||
      FinancialIntelligenceModelParityStatus.unsupported =>
        FinancialRecommendationConfidence.low,
      _ => FinancialRecommendationConfidence.medium,
    };
  }

  FinancialRecommendationPriority _priorityFor(
    FinancialIntelligenceDecisionOption selected,
  ) {
    return switch (selected.type) {
      FinancialIntelligenceDecisionOptionType.reduceReducibleSpending ||
      FinancialIntelligenceDecisionOptionType
          .deferOrReduceDiscretionarySpending =>
        FinancialRecommendationPriority.medium,
      _ => FinancialRecommendationPriority.medium,
    };
  }

  FinancialDecisionOptionType? _runtimeTypeFor(
    FinancialIntelligenceDecisionOptionType type,
  ) {
    return switch (type) {
      FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
        FinancialDecisionOptionType.reviewExpenseStructure,
      FinancialIntelligenceDecisionOptionType.reduceReducibleSpending =>
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      FinancialIntelligenceDecisionOptionType
          .deferOrReduceDiscretionarySpending =>
        FinancialDecisionOptionType.deferOptionalSpending,
      FinancialIntelligenceDecisionOptionType.improveCategoryCoverage =>
        FinancialDecisionOptionType.improveCategorization,
      _ => null,
    };
  }

  FinancialIntelligenceRecommendationType? _comparisonTypeFor(
    FinancialIntelligenceDecisionOptionType type,
  ) {
    return switch (type) {
      FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
        FinancialIntelligenceRecommendationType.reviewOrdinarySpendingStructure,
      FinancialIntelligenceDecisionOptionType.reduceReducibleSpending =>
        FinancialIntelligenceRecommendationType.reduceReducibleSpending,
      FinancialIntelligenceDecisionOptionType
          .deferOrReduceDiscretionarySpending =>
        FinancialIntelligenceRecommendationType
            .deferOrReduceDiscretionarySpending,
      FinancialIntelligenceDecisionOptionType.improveCategoryCoverage =>
        FinancialIntelligenceRecommendationType.improveCategoryCoverage,
      FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts =>
        FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
      FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum =>
        FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum,
      FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
        FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
      FinancialIntelligenceDecisionOptionType.reviewTransactionContext =>
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
    };
  }

  List<FinancialProblemType> _legacyProblemTypesFor(
    FinancialIntelligenceDecisionOption option,
  ) {
    final mapped = [
      for (final problemType in option.sourceProblemTypes)
        _legacyProblemTypeFor(problemType),
    ];
    if (mapped.isEmpty) {
      return switch (option.type) {
        FinancialIntelligenceDecisionOptionType.improveCategoryCoverage =>
          const [FinancialProblemType.poorDataReliability],
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending ||
        FinancialIntelligenceDecisionOptionType
            .deferOrReduceDiscretionarySpending => const [
          FinancialProblemType.discretionarySpendingPressure,
        ],
        _ => const [FinancialProblemType.expensePressure],
      };
    }
    return {...mapped}.toList(growable: false);
  }

  FinancialProblemType _legacyProblemTypeFor(
    FinancialIntelligenceProblemType type,
  ) {
    return switch (type) {
      FinancialIntelligenceProblemType.classificationCoverageGap =>
        FinancialProblemType.poorDataReliability,
      FinancialIntelligenceProblemType.discretionarySpendingPressure ||
      FinancialIntelligenceProblemType.reducibleSpendingPressure =>
        FinancialProblemType.discretionarySpendingPressure,
      FinancialIntelligenceProblemType.mandatoryCostPressure =>
        FinancialProblemType.essentialCostPressure,
      FinancialIntelligenceProblemType.transactionContextRequired =>
        FinancialProblemType.poorDataReliability,
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal =>
        FinancialProblemType.weakSavingsCapacity,
      FinancialIntelligenceProblemType.debtReductionSignal =>
        FinancialProblemType.fixedCommitmentPressure,
      FinancialIntelligenceProblemType.ordinarySpendingPressure =>
        FinancialProblemType.expensePressure,
    };
  }

  List<String> _modelIdsFor(FinancialIntelligenceDecisionOption option) {
    final metric = option.parityMetric;
    if (metric == null) {
      return const [];
    }
    return ['financial.intelligence.parity.${metric.name}'];
  }

  String _runtimeOptionId(String sourceOptionId) {
    return 'financial.intelligence.runtime.option.$sourceOptionId';
  }
}

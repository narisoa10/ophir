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
import 'package:ophir/features/assistant/domain/entities/financial_explanation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_edge.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_edge_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_graph.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_node.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_node_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_source_layer.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_step.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_flag.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_read_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_conflict_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_evaluation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_priority.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_reversibility.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_status.dart';

FinancialRecommendation buildTestFinancialRecommendation(
  FinancialDecisionOptionType type,
) {
  final option = buildTestFinancialDecisionOption(type);

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

FinancialDecisionOption buildTestFinancialDecisionOption(
  FinancialDecisionOptionType type,
) {
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

FinancialExplanation buildTestFinancialExplanation(
  FinancialRecommendation recommendation,
) {
  final recommendationNodeId =
      'explanation.node.${recommendation.recommendationId}';
  final optionNodeId = 'explanation.node.${recommendation.selectedOptionId}';

  return FinancialExplanation(
    explanationId: 'explanation.${recommendation.recommendationId}',
    explanationType: FinancialExplanationType.recommendationSelection,
    status: FinancialExplanationStatus.complete,
    confidence: FinancialExplanationConfidence.medium,
    graph: FinancialExplanationGraph(
      nodes: [
        FinancialExplanationNode(
          id: recommendationNodeId,
          nodeType: FinancialExplanationNodeType.recommendation,
          sourceLayer: FinancialExplanationSourceLayer.recommendation,
          referencedEntityIds: [recommendation.recommendationId],
          confidence: FinancialExplanationConfidence.medium,
          evidence: const [],
          assumptions: const [],
          limitations: const [],
          children: [optionNodeId],
          parents: const [],
        ),
        FinancialExplanationNode(
          id: optionNodeId,
          nodeType: FinancialExplanationNodeType.selectedOption,
          sourceLayer: FinancialExplanationSourceLayer.decisionOption,
          referencedEntityIds: [recommendation.selectedOptionId],
          confidence: FinancialExplanationConfidence.medium,
          evidence: const [],
          assumptions: const [],
          limitations: const [],
          children: const [],
          parents: [recommendationNodeId],
        ),
      ],
      edges: [
        FinancialExplanationEdge(
          id: 'explanation.edge.${recommendation.recommendationId}',
          fromNodeId: recommendationNodeId,
          toNodeId: optionNodeId,
          edgeType: FinancialExplanationEdgeType.selected,
        ),
      ],
      rootNodeId: recommendationNodeId,
    ),
    steps: [
      FinancialExplanationStep(
        stepId: 'explanation.step.${recommendation.recommendationId}',
        explanationType: FinancialExplanationType.recommendationSelection,
        nodeIds: [recommendationNodeId, optionNodeId],
      ),
    ],
    validationIssues: const [],
    metadata: FinancialExplanationMetadata(
      generatedAt: DateTime.utc(2035, 6),
      engineVersion: 'test',
    ),
  );
}

FinancialRecommendationComparisonReadModel buildTestRecommendationComparison({
  required FinancialDecisionOptionType? legacyType,
  required List<FinancialIntelligenceRecommendationType> shadowTypes,
  required FinancialRecommendationConflictLevel conflictLevel,
  bool hasPositiveSignals = false,
  bool hasContextWarnings = false,
  bool hasCoverageWarnings = false,
  List<FinancialRecommendationComparisonFlag> flags = const [],
}) {
  return FinancialRecommendationComparisonReadModel(
    legacyRecommendationType: legacyType,
    shadowRecommendationTypes: shadowTypes,
    hasShadowDiagnostics: shadowTypes.isNotEmpty,
    hasPositiveSignals: hasPositiveSignals,
    hasContextWarnings: hasContextWarnings,
    hasCoverageWarnings: hasCoverageWarnings,
    conflictLevel: conflictLevel,
    flags: flags,
  );
}

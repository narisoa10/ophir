import '../entities/financial_explanation.dart';
import '../entities/financial_explanation_confidence.dart';
import '../entities/financial_explanation_edge.dart';
import '../entities/financial_explanation_edge_type.dart';
import '../entities/financial_explanation_evidence.dart';
import '../entities/financial_explanation_graph.dart';
import '../entities/financial_explanation_metadata.dart';
import '../entities/financial_explanation_node.dart';
import '../entities/financial_explanation_node_type.dart';
import '../entities/financial_explanation_reference.dart';
import '../entities/financial_explanation_reference_type.dart';
import '../entities/financial_explanation_source_layer.dart';
import '../entities/financial_explanation_status.dart';
import '../entities/financial_explanation_step.dart';
import '../entities/financial_explanation_type.dart';
import '../entities/financial_explanation_validation_issue.dart';
import '../entities/financial_intelligence_recommendation_explanation_snapshot.dart';
import '../entities/financial_intelligence_recommendation_selection_snapshot.dart';
import '../entities/financial_recommendation.dart';
import '../entities/financial_recommendation_confidence.dart';

final class FinancialIntelligenceRuntimeExplanationAdapter {
  const FinancialIntelligenceRuntimeExplanationAdapter();

  FinancialExplanation? adapt({
    required FinancialRecommendation recommendation,
    required FinancialIntelligenceRecommendationSelectionSnapshot selection,
    required FinancialIntelligenceRecommendationExplanationSnapshot explanation,
    required DateTime generatedAt,
  }) {
    final selected = selection.selectedOption;
    final sourceExplanation = explanation.explanation;
    final explained = sourceExplanation.selectedRecommendation;
    if (selected == null ||
        explained == null ||
        selected.optionId != explained.optionId ||
        !selection.isDiagnosticsOnly ||
        !selected.isDiagnosticsOnly ||
        !sourceExplanation.isDiagnosticsOnly ||
        sourceExplanation.evidence.isEmpty ||
        !sourceExplanation.evidence.any(
          (evidence) => evidence.sourceOptionId == selected.optionId,
        )) {
      return null;
    }

    final rootNodeId = _nodeId(
      'recommendation',
      recommendation.recommendationId,
    );
    final optionNodeId = _nodeId('option', recommendation.selectedOptionId);
    final problemNodeIds = [
      for (final problem in sourceExplanation.supportingProblems)
        _nodeId('problem', problem.problemId),
    ];
    final modelNodeIds = [
      for (final metric in sourceExplanation.supportingParityMetrics)
        _nodeId('model', metric.metric.name),
    ];
    final evidenceNodeIds = [
      for (final evidence in sourceExplanation.evidence)
        _nodeId('evidence', evidence.evidenceId),
    ];

    final nodes = [
      FinancialExplanationNode(
        id: rootNodeId,
        nodeType: FinancialExplanationNodeType.recommendation,
        sourceLayer: FinancialExplanationSourceLayer.recommendation,
        referencedEntityIds: [recommendation.recommendationId],
        confidence: _explanationConfidence(recommendation.confidence),
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
        confidence: _explanationConfidence(recommendation.confidence),
        evidence: [
          for (final evidence in sourceExplanation.evidence)
            FinancialExplanationEvidence(
              evidenceId: _runtimeEvidenceId(evidence.evidenceId),
              sourceEntityId: evidence.sourceOptionId,
              references: [
                FinancialExplanationReference(
                  referenceId: recommendation.selectedOptionId,
                  referenceType:
                      FinancialExplanationReferenceType.decisionOption,
                  sourceLayer: FinancialExplanationSourceLayer.decisionOption,
                ),
                for (final problemId in evidence.sourceProblemIds)
                  FinancialExplanationReference(
                    referenceId: problemId,
                    referenceType: FinancialExplanationReferenceType.problem,
                    sourceLayer: FinancialExplanationSourceLayer.problem,
                  ),
                for (final metric in evidence.parityMetrics)
                  FinancialExplanationReference(
                    referenceId: metric.name,
                    referenceType:
                        FinancialExplanationReferenceType.modelResult,
                    sourceLayer: FinancialExplanationSourceLayer.model,
                  ),
              ],
            ),
        ],
        assumptions: const [],
        limitations: const [],
        children: [...problemNodeIds, ...modelNodeIds, ...evidenceNodeIds],
        parents: [rootNodeId],
      ),
      for (final problem in sourceExplanation.supportingProblems)
        FinancialExplanationNode(
          id: _nodeId('problem', problem.problemId),
          nodeType: FinancialExplanationNodeType.problem,
          sourceLayer: FinancialExplanationSourceLayer.problem,
          referencedEntityIds: [problem.problemId],
          confidence: _explanationConfidence(recommendation.confidence),
          evidence: const [],
          assumptions: const [],
          limitations: const [],
          children: const [],
          parents: [optionNodeId],
        ),
      for (final metric in sourceExplanation.supportingParityMetrics)
        FinancialExplanationNode(
          id: _nodeId('model', metric.metric.name),
          nodeType: FinancialExplanationNodeType.modelResult,
          sourceLayer: FinancialExplanationSourceLayer.model,
          referencedEntityIds: [metric.metric.name],
          confidence: _explanationConfidence(recommendation.confidence),
          evidence: const [],
          assumptions: const [],
          limitations: const [],
          children: const [],
          parents: [optionNodeId],
        ),
      for (final evidence in sourceExplanation.evidence)
        FinancialExplanationNode(
          id: _nodeId('evidence', evidence.evidenceId),
          nodeType: FinancialExplanationNodeType.evidence,
          sourceLayer: FinancialExplanationSourceLayer.decisionOption,
          referencedEntityIds: [evidence.evidenceId],
          confidence: _explanationConfidence(recommendation.confidence),
          evidence: const [],
          assumptions: const [],
          limitations: const [],
          children: const [],
          parents: [optionNodeId],
        ),
    ];
    final edges = [
      FinancialExplanationEdge(
        id: _edgeId(rootNodeId, optionNodeId),
        fromNodeId: rootNodeId,
        toNodeId: optionNodeId,
        edgeType: FinancialExplanationEdgeType.selected,
      ),
      for (final nodeId in [...problemNodeIds, ...modelNodeIds])
        FinancialExplanationEdge(
          id: _edgeId(optionNodeId, nodeId),
          fromNodeId: optionNodeId,
          toNodeId: nodeId,
          edgeType: FinancialExplanationEdgeType.supportedBy,
        ),
      for (final nodeId in evidenceNodeIds)
        FinancialExplanationEdge(
          id: _edgeId(optionNodeId, nodeId),
          fromNodeId: optionNodeId,
          toNodeId: nodeId,
          edgeType: FinancialExplanationEdgeType.referencesEvidence,
        ),
    ];
    final steps = [
      FinancialExplanationStep(
        stepId: _stepId('selection', recommendation.recommendationId),
        explanationType: FinancialExplanationType.recommendationSelection,
        nodeIds: [rootNodeId, optionNodeId],
      ),
      FinancialExplanationStep(
        stepId: _stepId('support', recommendation.recommendationId),
        explanationType: FinancialExplanationType.recommendationSelection,
        nodeIds: [
          optionNodeId,
          ...problemNodeIds,
          ...modelNodeIds,
          ...evidenceNodeIds,
        ],
      ),
    ];
    final graph = FinancialExplanationGraph(
      nodes: nodes,
      edges: edges,
      rootNodeId: rootNodeId,
    );
    if (!_isValid(graph: graph, steps: steps)) {
      return null;
    }

    return FinancialExplanation(
      explanationId:
          'financial.intelligence.runtime.explanation.'
          '${recommendation.recommendationId}',
      explanationType: FinancialExplanationType.recommendationSelection,
      status: FinancialExplanationStatus.complete,
      confidence: _explanationConfidence(recommendation.confidence),
      graph: graph,
      steps: steps,
      validationIssues: const <FinancialExplanationValidationIssue>[],
      metadata: FinancialExplanationMetadata(
        generatedAt: generatedAt,
        engineVersion: 'financial-intelligence-runtime-adapter-v1',
      ),
    );
  }

  bool _isValid({
    required FinancialExplanationGraph graph,
    required List<FinancialExplanationStep> steps,
  }) {
    if (graph.nodes.isEmpty || steps.isEmpty) {
      return false;
    }
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    if (!nodeIds.contains(graph.rootNodeId)) {
      return false;
    }
    if (graph.edges.any(
      (edge) =>
          !nodeIds.contains(edge.fromNodeId) ||
          !nodeIds.contains(edge.toNodeId),
    )) {
      return false;
    }
    return steps.every(
      (step) =>
          step.nodeIds.isNotEmpty &&
          step.nodeIds.every((nodeId) => nodeIds.contains(nodeId)),
    );
  }

  FinancialExplanationConfidence _explanationConfidence(
    FinancialRecommendationConfidence confidence,
  ) {
    return switch (confidence) {
      FinancialRecommendationConfidence.none =>
        FinancialExplanationConfidence.none,
      FinancialRecommendationConfidence.low =>
        FinancialExplanationConfidence.low,
      FinancialRecommendationConfidence.medium =>
        FinancialExplanationConfidence.medium,
      FinancialRecommendationConfidence.high =>
        FinancialExplanationConfidence.high,
    };
  }

  String _nodeId(String kind, String sourceId) {
    return 'financial.intelligence.runtime.explanation.node.$kind.$sourceId';
  }

  String _edgeId(String from, String to) {
    return 'financial.intelligence.runtime.explanation.edge.$from.$to';
  }

  String _stepId(String kind, String recommendationId) {
    return 'financial.intelligence.runtime.explanation.step.'
        '$kind.$recommendationId';
  }

  String _runtimeEvidenceId(String sourceEvidenceId) {
    return 'financial.intelligence.runtime.explanation.evidence.'
        '$sourceEvidenceId';
  }
}

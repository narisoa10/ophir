import '../entities/financial_decision_option.dart';
import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_confidence.dart' as deviation;
import '../entities/financial_explanation_assumption.dart';
import '../entities/financial_explanation_confidence.dart';
import '../entities/financial_explanation_edge.dart';
import '../entities/financial_explanation_edge_type.dart';
import '../entities/financial_explanation_evidence.dart';
import '../entities/financial_explanation_graph.dart';
import '../entities/financial_explanation_limitation.dart';
import '../entities/financial_explanation_node.dart';
import '../entities/financial_explanation_node_type.dart';
import '../entities/financial_explanation_reference_index.dart';
import '../entities/financial_explanation_source_layer.dart';
import '../entities/financial_explanation_fact_reference.dart';
import '../entities/financial_fact_confidence.dart' as fact;
import '../entities/financial_model_confidence.dart' as model;
import '../entities/financial_model_result.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_confidence.dart' as problem;
import '../entities/financial_recommendation.dart';
import '../entities/financial_recommendation_confidence.dart' as recommendation;
import 'financial_explanation_evidence_builder.dart';
import 'financial_explanation_reference_resolver.dart';

final class FinancialExplanationGraphBuilder {
  const FinancialExplanationGraphBuilder({
    this.resolver = const FinancialExplanationReferenceResolver(),
    this.evidenceBuilder = const FinancialExplanationEvidenceBuilder(),
  });

  final FinancialExplanationReferenceResolver resolver;
  final FinancialExplanationEvidenceBuilder evidenceBuilder;

  FinancialExplanationGraph build(
    FinancialRecommendation recommendationValue,
    FinancialExplanationReferenceIndex index,
  ) {
    final draft = _GraphDraft();
    final rootNodeId = _recommendationNodeId(
      recommendationValue.recommendationId,
    );

    draft.addNode(
      _DraftNode(
        id: rootNodeId,
        nodeType: FinancialExplanationNodeType.recommendation,
        sourceLayer: FinancialExplanationSourceLayer.recommendation,
        referencedEntityIds: [recommendationValue.recommendationId],
        confidence: _fromRecommendationConfidence(
          recommendationValue.confidence,
        ),
        evidence: [evidenceBuilder.fromRecommendation(recommendationValue)],
        assumptions: const [],
        limitations: const [],
      ),
    );

    final selectedOption = recommendationValue.selectedOption;
    final selectedNodeId = _optionNodeId(
      selectedOption.optionId,
      selected: true,
    );
    _addOptionBranch(
      draft,
      selectedOption,
      index,
      nodeId: selectedNodeId,
      nodeType: FinancialExplanationNodeType.selectedOption,
    );
    draft.addEdge(
      rootNodeId,
      selectedNodeId,
      FinancialExplanationEdgeType.selected,
    );

    final alternatives = recommendationValue.rejectedAlternatives.toList()
      ..sort((a, b) => a.optionId.compareTo(b.optionId));
    for (final alternative in alternatives) {
      final alternativeNodeId = _rejectedNodeId(alternative.optionId);
      draft.addNode(
        _DraftNode(
          id: alternativeNodeId,
          nodeType: FinancialExplanationNodeType.rejectedAlternative,
          sourceLayer: FinancialExplanationSourceLayer.recommendation,
          referencedEntityIds: [
            alternative.optionId,
            ...alternative.reasonCodes.map((reason) => reason.name),
          ],
          confidence: FinancialExplanationConfidence.none,
          evidence: [evidenceBuilder.fromRejectedAlternative(alternative)],
          assumptions: const [],
          limitations: const [],
        ),
      );
      draft.addEdge(
        rootNodeId,
        alternativeNodeId,
        FinancialExplanationEdgeType.rejected,
      );

      final option = resolver.option(index, alternative.optionId);
      if (option != null) {
        final optionNodeId = _optionNodeId(option.optionId);
        _addOptionBranch(
          draft,
          option,
          index,
          nodeId: optionNodeId,
          nodeType: FinancialExplanationNodeType.decisionOption,
        );
        draft.addEdge(
          alternativeNodeId,
          optionNodeId,
          FinancialExplanationEdgeType.supportedBy,
        );
      }
    }

    return draft.toGraph(rootNodeId);
  }

  void _addOptionBranch(
    _GraphDraft draft,
    FinancialDecisionOption option,
    FinancialExplanationReferenceIndex index, {
    required String nodeId,
    required FinancialExplanationNodeType nodeType,
  }) {
    draft.addNode(
      _DraftNode(
        id: nodeId,
        nodeType: nodeType,
        sourceLayer: FinancialExplanationSourceLayer.decisionOption,
        referencedEntityIds: [option.optionId],
        confidence: _optionConfidence(option),
        evidence: [evidenceBuilder.fromOption(option)],
        assumptions: const [],
        limitations: [
          ...option.limitations.map(
            (value) => FinancialExplanationLimitation(
              limitationId: value.limitationId,
              sourceLayer: FinancialExplanationSourceLayer.decisionOption,
              sourceEntityId: option.optionId,
            ),
          ),
          ...option.conditions.map(
            (value) => FinancialExplanationLimitation(
              limitationId: value.conditionId,
              sourceLayer: FinancialExplanationSourceLayer.decisionOption,
              sourceEntityId: option.optionId,
            ),
          ),
        ],
      ),
    );

    for (final problemId in _sorted(option.evidence.sourceProblemIds)) {
      final sourceProblem = resolver.problem(index, problemId);
      if (sourceProblem == null) {
        continue;
      }
      final problemNodeId = _problemNodeId(problemId);
      _addProblemBranch(draft, sourceProblem, index);
      draft.addEdge(
        nodeId,
        problemNodeId,
        FinancialExplanationEdgeType.supportedBy,
      );
    }
  }

  void _addProblemBranch(
    _GraphDraft draft,
    FinancialProblem sourceProblem,
    FinancialExplanationReferenceIndex index,
  ) {
    final nodeId = _problemNodeId(sourceProblem.problemId);
    draft.addNode(
      _DraftNode(
        id: nodeId,
        nodeType: FinancialExplanationNodeType.problem,
        sourceLayer: FinancialExplanationSourceLayer.problem,
        referencedEntityIds: [sourceProblem.problemId],
        confidence: _fromProblemConfidence(sourceProblem.confidence),
        evidence: [evidenceBuilder.fromProblem(sourceProblem)],
        assumptions: const [],
        limitations: sourceProblem.limitations
            .map(
              (value) => FinancialExplanationLimitation(
                limitationId: value.name,
                sourceLayer: FinancialExplanationSourceLayer.problem,
                sourceEntityId: sourceProblem.problemId,
              ),
            )
            .toList(),
      ),
    );

    for (final deviationId in _sorted(
      sourceProblem.evidence.sourceDeviationIds,
    )) {
      final sourceDeviation = resolver.deviation(index, deviationId);
      if (sourceDeviation == null) {
        continue;
      }
      final deviationNodeId = _deviationNodeId(deviationId);
      _addDeviationBranch(draft, sourceDeviation, index);
      draft.addEdge(
        nodeId,
        deviationNodeId,
        FinancialExplanationEdgeType.derivedFrom,
      );
    }

    for (final modelId in _sorted(sourceProblem.evidence.sourceModelIds)) {
      final result = resolver.modelResult(index, modelId);
      if (result == null) {
        continue;
      }
      final modelNodeId = _modelNodeId(modelId);
      _addModelBranch(draft, result, index);
      draft.addEdge(
        nodeId,
        modelNodeId,
        FinancialExplanationEdgeType.derivedFrom,
      );
    }
  }

  void _addDeviationBranch(
    _GraphDraft draft,
    FinancialDeviation sourceDeviation,
    FinancialExplanationReferenceIndex index,
  ) {
    final nodeId = _deviationNodeId(sourceDeviation.deviationId);
    draft.addNode(
      _DraftNode(
        id: nodeId,
        nodeType: FinancialExplanationNodeType.deviation,
        sourceLayer: FinancialExplanationSourceLayer.deviation,
        referencedEntityIds: [sourceDeviation.deviationId],
        confidence: _fromDeviationConfidence(sourceDeviation.confidence),
        evidence: [evidenceBuilder.fromDeviation(sourceDeviation)],
        assumptions: const [],
        limitations: sourceDeviation.limitations
            .map(
              (value) => FinancialExplanationLimitation(
                limitationId: value.name,
                sourceLayer: FinancialExplanationSourceLayer.deviation,
                sourceEntityId: sourceDeviation.deviationId,
              ),
            )
            .toList(),
      ),
    );

    for (final modelId in _sorted(sourceDeviation.evidence.sourceModelIds)) {
      final result = resolver.modelResult(index, modelId);
      if (result == null) {
        continue;
      }
      final modelNodeId = _modelNodeId(modelId);
      _addModelBranch(draft, result, index);
      draft.addEdge(
        nodeId,
        modelNodeId,
        FinancialExplanationEdgeType.derivedFrom,
      );
    }

    for (final factId in _sorted(
      sourceDeviation.evidence.sourceModelEvidenceFactIds,
    )) {
      final sourceFact = resolver.fact(index, factId);
      if (sourceFact == null) {
        continue;
      }
      final factNodeId = _factNodeId(factId);
      _addFactNode(draft, sourceFact);
      draft.addEdge(
        nodeId,
        factNodeId,
        FinancialExplanationEdgeType.derivedFrom,
      );
    }
  }

  void _addModelBranch(
    _GraphDraft draft,
    FinancialModelResult result,
    FinancialExplanationReferenceIndex index,
  ) {
    final nodeId = _modelNodeId(result.modelId);
    draft.addNode(
      _DraftNode(
        id: nodeId,
        nodeType: FinancialExplanationNodeType.modelResult,
        sourceLayer: FinancialExplanationSourceLayer.model,
        referencedEntityIds: [result.modelId],
        confidence: _fromModelConfidence(result.modelConfidence),
        evidence: [evidenceBuilder.fromModelResult(result)],
        assumptions: result.assumptions
            .map(
              (value) => FinancialExplanationAssumption(
                assumptionId: value,
                sourceLayer: FinancialExplanationSourceLayer.model,
                sourceEntityId: result.modelId,
              ),
            )
            .toList(),
        limitations: result.limitations
            .map(
              (value) => FinancialExplanationLimitation(
                limitationId: value.name,
                sourceLayer: FinancialExplanationSourceLayer.model,
                sourceEntityId: result.modelId,
              ),
            )
            .toList(),
      ),
    );

    for (final factId in _sorted(result.evidence.factIds)) {
      final sourceFact = resolver.fact(index, factId);
      if (sourceFact == null) {
        continue;
      }
      final factNodeId = _factNodeId(factId);
      _addFactNode(draft, sourceFact);
      draft.addEdge(
        nodeId,
        factNodeId,
        FinancialExplanationEdgeType.derivedFrom,
      );
    }
  }

  void _addFactNode(
    _GraphDraft draft,
    FinancialExplanationFactReference sourceFact,
  ) {
    draft.addNode(
      _DraftNode(
        id: _factNodeId(sourceFact.factId),
        nodeType: FinancialExplanationNodeType.fact,
        sourceLayer: FinancialExplanationSourceLayer.fact,
        referencedEntityIds: [sourceFact.factId],
        confidence: _fromFactConfidence(sourceFact.confidence),
        evidence: [
          FinancialExplanationEvidence(
            evidenceId: 'evidence.${sourceFact.factId}',
            sourceEntityId: sourceFact.factId,
            references: const [],
          ),
        ],
        assumptions: const [],
        limitations: const [],
      ),
    );
  }

  FinancialExplanationConfidence _optionConfidence(
    FinancialDecisionOption option,
  ) {
    final confidences = [
      ...option.targets.map((target) => target.confidence),
      ...option.expectedModelChanges.map((change) => change.confidence),
    ];
    if (confidences.isEmpty) {
      return FinancialExplanationConfidence.none;
    }
    return confidences
        .map(_fromProblemConfidence)
        .reduce(
          (value, element) => value.index < element.index ? value : element,
        );
  }

  FinancialExplanationConfidence _fromRecommendationConfidence(
    recommendation.FinancialRecommendationConfidence confidence,
  ) {
    return switch (confidence) {
      recommendation.FinancialRecommendationConfidence.none =>
        FinancialExplanationConfidence.none,
      recommendation.FinancialRecommendationConfidence.low =>
        FinancialExplanationConfidence.low,
      recommendation.FinancialRecommendationConfidence.medium =>
        FinancialExplanationConfidence.medium,
      recommendation.FinancialRecommendationConfidence.high =>
        FinancialExplanationConfidence.high,
    };
  }

  FinancialExplanationConfidence _fromProblemConfidence(
    problem.FinancialProblemConfidence confidence,
  ) {
    return switch (confidence) {
      problem.FinancialProblemConfidence.none =>
        FinancialExplanationConfidence.none,
      problem.FinancialProblemConfidence.low =>
        FinancialExplanationConfidence.low,
      problem.FinancialProblemConfidence.medium =>
        FinancialExplanationConfidence.medium,
      problem.FinancialProblemConfidence.high =>
        FinancialExplanationConfidence.high,
    };
  }

  FinancialExplanationConfidence _fromDeviationConfidence(
    deviation.FinancialDeviationConfidence confidence,
  ) {
    return switch (confidence) {
      deviation.FinancialDeviationConfidence.none =>
        FinancialExplanationConfidence.none,
      deviation.FinancialDeviationConfidence.low =>
        FinancialExplanationConfidence.low,
      deviation.FinancialDeviationConfidence.medium =>
        FinancialExplanationConfidence.medium,
      deviation.FinancialDeviationConfidence.high =>
        FinancialExplanationConfidence.high,
    };
  }

  FinancialExplanationConfidence _fromModelConfidence(
    model.FinancialModelConfidence confidence,
  ) {
    return switch (confidence) {
      model.FinancialModelConfidence.none =>
        FinancialExplanationConfidence.none,
      model.FinancialModelConfidence.low => FinancialExplanationConfidence.low,
      model.FinancialModelConfidence.medium =>
        FinancialExplanationConfidence.medium,
      model.FinancialModelConfidence.high =>
        FinancialExplanationConfidence.high,
    };
  }

  FinancialExplanationConfidence _fromFactConfidence(
    fact.FinancialFactConfidence confidence,
  ) {
    return switch (confidence) {
      fact.FinancialFactConfidence.low => FinancialExplanationConfidence.low,
      fact.FinancialFactConfidence.medium =>
        FinancialExplanationConfidence.medium,
      fact.FinancialFactConfidence.high => FinancialExplanationConfidence.high,
    };
  }

  List<String> _sorted(Iterable<String> values) {
    return values.toSet().toList()..sort();
  }

  String _recommendationNodeId(String id) => 'recommendation.$id';
  String _optionNodeId(String id, {bool selected = false}) =>
      selected ? 'selectedOption.$id' : 'option.$id';
  String _rejectedNodeId(String id) => 'rejectedAlternative.$id';
  String _problemNodeId(String id) => 'problem.$id';
  String _deviationNodeId(String id) => 'deviation.$id';
  String _modelNodeId(String id) => 'model.$id';
  String _factNodeId(String id) => 'fact.$id';
}

final class _GraphDraft {
  final Map<String, _DraftNode> _nodes = {};
  final Map<String, _DraftEdge> _edges = {};

  void addNode(_DraftNode node) {
    _nodes.putIfAbsent(node.id, () => node);
  }

  void addEdge(
    String fromNodeId,
    String toNodeId,
    FinancialExplanationEdgeType edgeType,
  ) {
    final id = '$fromNodeId.${edgeType.name}.$toNodeId';
    _edges.putIfAbsent(
      id,
      () => _DraftEdge(
        id: id,
        fromNodeId: fromNodeId,
        toNodeId: toNodeId,
        edgeType: edgeType,
      ),
    );
  }

  FinancialExplanationGraph toGraph(String rootNodeId) {
    final parentsByNode = <String, List<String>>{};
    final childrenByNode = <String, List<String>>{};
    for (final edge in _edges.values) {
      childrenByNode.putIfAbsent(edge.fromNodeId, () => []).add(edge.toNodeId);
      parentsByNode.putIfAbsent(edge.toNodeId, () => []).add(edge.fromNodeId);
    }

    final nodes = _nodes.values.map((node) {
      final parents = parentsByNode[node.id] ?? const <String>[];
      final children = childrenByNode[node.id] ?? const <String>[];
      return FinancialExplanationNode(
        id: node.id,
        nodeType: node.nodeType,
        sourceLayer: node.sourceLayer,
        referencedEntityIds: List.unmodifiable(
          _sortedStrings(node.referencedEntityIds),
        ),
        confidence: node.confidence,
        evidence: List.unmodifiable(node.evidence),
        assumptions: List.unmodifiable(node.assumptions),
        limitations: List.unmodifiable(node.limitations),
        children: List.unmodifiable(_sortedStrings(children)),
        parents: List.unmodifiable(_sortedStrings(parents)),
      );
    }).toList()..sort((a, b) => a.id.compareTo(b.id));

    final edges =
        _edges.values
            .map(
              (edge) => FinancialExplanationEdge(
                id: edge.id,
                fromNodeId: edge.fromNodeId,
                toNodeId: edge.toNodeId,
                edgeType: edge.edgeType,
              ),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    return FinancialExplanationGraph(
      nodes: List.unmodifiable(nodes),
      edges: List.unmodifiable(edges),
      rootNodeId: rootNodeId,
    );
  }

  List<String> _sortedStrings(Iterable<String> values) {
    return values.toSet().toList()..sort();
  }
}

final class _DraftNode {
  const _DraftNode({
    required this.id,
    required this.nodeType,
    required this.sourceLayer,
    required this.referencedEntityIds,
    required this.confidence,
    required this.evidence,
    required this.assumptions,
    required this.limitations,
  });

  final String id;
  final FinancialExplanationNodeType nodeType;
  final FinancialExplanationSourceLayer sourceLayer;
  final List<String> referencedEntityIds;
  final FinancialExplanationConfidence confidence;
  final List<FinancialExplanationEvidence> evidence;
  final List<FinancialExplanationAssumption> assumptions;
  final List<FinancialExplanationLimitation> limitations;
}

final class _DraftEdge {
  const _DraftEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.edgeType,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final FinancialExplanationEdgeType edgeType;
}

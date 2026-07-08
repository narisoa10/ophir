import '../entities/financial_explanation_graph.dart';
import '../entities/financial_explanation_reference_type.dart';
import '../entities/financial_explanation_validation_issue.dart';
import '../entities/financial_explanation_validation_issue_type.dart';

final class FinancialExplanationValidationService {
  const FinancialExplanationValidationService();

  List<FinancialExplanationValidationIssue> validate(
    FinancialExplanationGraph graph,
  ) {
    final issues = <FinancialExplanationValidationIssue>[
      ..._invalidEdges(graph),
      ..._missingReferences(graph),
      ..._cycleIssues(graph),
    ];
    issues.sort((a, b) {
      final type = a.issueType.index.compareTo(b.issueType.index);
      if (type != 0) {
        return type;
      }
      final source = a.sourceNodeId.compareTo(b.sourceNodeId);
      if (source != 0) {
        return source;
      }
      return a.referenceId.compareTo(b.referenceId);
    });
    return List.unmodifiable(issues);
  }

  List<FinancialExplanationValidationIssue> _invalidEdges(
    FinancialExplanationGraph graph,
  ) {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    return graph.edges
        .where(
          (edge) =>
              !nodeIds.contains(edge.fromNodeId) ||
              !nodeIds.contains(edge.toNodeId),
        )
        .map(
          (edge) => FinancialExplanationValidationIssue(
            issueType: FinancialExplanationValidationIssueType.invalidEdge,
            sourceNodeId: edge.fromNodeId,
            referenceId: edge.toNodeId,
          ),
        )
        .toList();
  }

  List<FinancialExplanationValidationIssue> _missingReferences(
    FinancialExplanationGraph graph,
  ) {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    final issues = <FinancialExplanationValidationIssue>[];

    for (final node in graph.nodes) {
      for (final evidence in node.evidence) {
        for (final reference in evidence.references) {
          if (!_referenceExists(
            nodeIds,
            reference.referenceType,
            reference.referenceId,
          )) {
            issues.add(
              FinancialExplanationValidationIssue(
                issueType:
                    FinancialExplanationValidationIssueType.missingReference,
                sourceNodeId: node.id,
                referenceId: reference.referenceId,
              ),
            );
          }
        }
      }
    }
    return issues;
  }

  bool _referenceExists(
    Set<String> nodeIds,
    FinancialExplanationReferenceType referenceType,
    String referenceId,
  ) {
    return switch (referenceType) {
      FinancialExplanationReferenceType.recommendation => nodeIds.contains(
        'recommendation.$referenceId',
      ),
      FinancialExplanationReferenceType.decisionOption =>
        nodeIds.contains('selectedOption.$referenceId') ||
            nodeIds.contains('option.$referenceId'),
      FinancialExplanationReferenceType.rejectedAlternative => nodeIds.contains(
        'rejectedAlternative.$referenceId',
      ),
      FinancialExplanationReferenceType.problem => nodeIds.contains(
        'problem.$referenceId',
      ),
      FinancialExplanationReferenceType.deviation => nodeIds.contains(
        'deviation.$referenceId',
      ),
      FinancialExplanationReferenceType.modelResult => nodeIds.contains(
        'model.$referenceId',
      ),
      FinancialExplanationReferenceType.fact => nodeIds.contains(
        'fact.$referenceId',
      ),
      FinancialExplanationReferenceType.evaluation ||
      FinancialExplanationReferenceType.condition ||
      FinancialExplanationReferenceType.limitation ||
      FinancialExplanationReferenceType.assumption ||
      FinancialExplanationReferenceType.evidence => true,
    };
  }

  List<FinancialExplanationValidationIssue> _cycleIssues(
    FinancialExplanationGraph graph,
  ) {
    final adjacency = <String, List<String>>{};
    for (final edge in graph.edges) {
      adjacency.putIfAbsent(edge.fromNodeId, () => []).add(edge.toNodeId);
    }

    final visiting = <String>{};
    final visited = <String>{};
    final issues = <FinancialExplanationValidationIssue>[];

    bool visit(String nodeId) {
      if (visiting.contains(nodeId)) {
        issues.add(
          FinancialExplanationValidationIssue(
            issueType: FinancialExplanationValidationIssueType.cycleDetected,
            sourceNodeId: nodeId,
            referenceId: nodeId,
          ),
        );
        return true;
      }
      if (visited.contains(nodeId)) {
        return false;
      }
      visiting.add(nodeId);
      for (final child in adjacency[nodeId] ?? const <String>[]) {
        visit(child);
      }
      visiting.remove(nodeId);
      visited.add(nodeId);
      return false;
    }

    for (final node in graph.nodes) {
      visit(node.id);
    }
    return issues;
  }
}

import '../entities/financial_explanation.dart';
import '../entities/financial_explanation_metadata.dart';
import '../entities/financial_explanation_reference_index.dart';
import '../entities/financial_explanation_status.dart';
import '../entities/financial_explanation_type.dart';
import '../entities/financial_explanation_validation_issue.dart';
import '../entities/financial_explanation_validation_issue_type.dart';
import '../entities/financial_recommendation.dart';
import 'financial_explanation_graph_builder.dart';
import 'financial_explanation_trace_service.dart';
import 'financial_explanation_validation_service.dart';

final class FinancialExplanationService {
  const FinancialExplanationService({
    required this.generatedAt,
    this.graphBuilder = const FinancialExplanationGraphBuilder(),
    this.validationService = const FinancialExplanationValidationService(),
    this.traceService = const FinancialExplanationTraceService(),
  });

  final DateTime generatedAt;
  final FinancialExplanationGraphBuilder graphBuilder;
  final FinancialExplanationValidationService validationService;
  final FinancialExplanationTraceService traceService;

  FinancialExplanation explain(
    FinancialRecommendation recommendation,
    FinancialExplanationReferenceIndex referenceIndex,
  ) {
    final graph = graphBuilder.build(recommendation, referenceIndex);
    final issues = validationService.validate(graph);
    final status = _statusFor(issues);
    final rootNode = graph.nodes.firstWhere(
      (node) => node.id == graph.rootNodeId,
    );

    return FinancialExplanation(
      explanationId: 'explanation.${recommendation.recommendationId}',
      explanationType: FinancialExplanationType.recommendationSelection,
      status: status,
      confidence: rootNode.confidence,
      graph: graph,
      steps: traceService.buildSteps(graph),
      validationIssues: issues,
      metadata: FinancialExplanationMetadata(
        generatedAt: generatedAt,
        engineVersion: 'financial-explanations-v1',
      ),
    );
  }

  FinancialExplanationStatus _statusFor(
    List<FinancialExplanationValidationIssue> issues,
  ) {
    if (issues.isEmpty) {
      return FinancialExplanationStatus.complete;
    }
    final hasInvalidIssue = issues.any(
      (issue) =>
          issue.issueType ==
              FinancialExplanationValidationIssueType.cycleDetected ||
          issue.issueType ==
              FinancialExplanationValidationIssueType.invalidEdge,
    );
    return hasInvalidIssue
        ? FinancialExplanationStatus.invalid
        : FinancialExplanationStatus.incomplete;
  }
}

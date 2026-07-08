import 'financial_explanation_confidence.dart';
import 'financial_explanation_graph.dart';
import 'financial_explanation_metadata.dart';
import 'financial_explanation_status.dart';
import 'financial_explanation_step.dart';
import 'financial_explanation_type.dart';
import 'financial_explanation_validation_issue.dart';

final class FinancialExplanation {
  const FinancialExplanation({
    required this.explanationId,
    required this.explanationType,
    required this.status,
    required this.confidence,
    required this.graph,
    required this.steps,
    required this.validationIssues,
    required this.metadata,
  });

  final String explanationId;
  final FinancialExplanationType explanationType;
  final FinancialExplanationStatus status;
  final FinancialExplanationConfidence confidence;
  final FinancialExplanationGraph graph;
  final List<FinancialExplanationStep> steps;
  final List<FinancialExplanationValidationIssue> validationIssues;
  final FinancialExplanationMetadata metadata;
}

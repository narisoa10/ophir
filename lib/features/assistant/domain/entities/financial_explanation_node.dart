import 'financial_explanation_assumption.dart';
import 'financial_explanation_confidence.dart';
import 'financial_explanation_evidence.dart';
import 'financial_explanation_limitation.dart';
import 'financial_explanation_node_type.dart';
import 'financial_explanation_source_layer.dart';

final class FinancialExplanationNode {
  const FinancialExplanationNode({
    required this.id,
    required this.nodeType,
    required this.sourceLayer,
    required this.referencedEntityIds,
    required this.confidence,
    required this.evidence,
    required this.assumptions,
    required this.limitations,
    required this.children,
    required this.parents,
  });

  final String id;
  final FinancialExplanationNodeType nodeType;
  final FinancialExplanationSourceLayer sourceLayer;
  final List<String> referencedEntityIds;
  final FinancialExplanationConfidence confidence;
  final List<FinancialExplanationEvidence> evidence;
  final List<FinancialExplanationAssumption> assumptions;
  final List<FinancialExplanationLimitation> limitations;
  final List<String> children;
  final List<String> parents;
}

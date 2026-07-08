import 'financial_explanation_edge_type.dart';

final class FinancialExplanationEdge {
  const FinancialExplanationEdge({
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

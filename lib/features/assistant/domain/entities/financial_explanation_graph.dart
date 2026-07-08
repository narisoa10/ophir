import 'financial_explanation_edge.dart';
import 'financial_explanation_node.dart';

final class FinancialExplanationGraph {
  const FinancialExplanationGraph({
    required this.nodes,
    required this.edges,
    required this.rootNodeId,
  });

  final List<FinancialExplanationNode> nodes;
  final List<FinancialExplanationEdge> edges;
  final String rootNodeId;
}

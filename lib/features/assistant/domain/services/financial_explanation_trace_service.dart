import '../entities/financial_explanation_graph.dart';
import '../entities/financial_explanation_step.dart';
import '../entities/financial_explanation_type.dart';

final class FinancialExplanationTraceService {
  const FinancialExplanationTraceService();

  List<FinancialExplanationStep> buildSteps(FinancialExplanationGraph graph) {
    final nodeIds = graph.nodes.map((node) => node.id).toList()..sort();
    return [
      FinancialExplanationStep(
        stepId: 'step.${graph.rootNodeId}',
        explanationType: FinancialExplanationType.recommendationSelection,
        nodeIds: List.unmodifiable(nodeIds),
      ),
    ];
  }
}

import 'financial_explanation_type.dart';

final class FinancialExplanationStep {
  const FinancialExplanationStep({
    required this.stepId,
    required this.explanationType,
    required this.nodeIds,
  });

  final String stepId;
  final FinancialExplanationType explanationType;
  final List<String> nodeIds;
}

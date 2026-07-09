import 'financial_intelligence_decision_option.dart';
import 'financial_intelligence_model_parity_metric_result.dart';
import 'financial_intelligence_problem.dart';
import 'financial_intelligence_recommendation_evidence.dart';
import 'financial_intelligence_recommendation_selection_reason.dart';

final class FinancialIntelligenceRecommendationExplanation {
  FinancialIntelligenceRecommendationExplanation({
    required this.selectedRecommendation,
    required this.selectionReason,
    required List<FinancialIntelligenceProblem> supportingProblems,
    required List<FinancialIntelligenceModelParityMetricResult>
    supportingParityMetrics,
    required List<FinancialIntelligenceRecommendationEvidence> evidence,
    required this.isDiagnosticsOnly,
  }) : supportingProblems = List.unmodifiable(supportingProblems),
       supportingParityMetrics = List.unmodifiable(supportingParityMetrics),
       evidence = List.unmodifiable(evidence);

  final FinancialIntelligenceDecisionOption? selectedRecommendation;
  final FinancialIntelligenceRecommendationSelectionReason selectionReason;
  final List<FinancialIntelligenceProblem> supportingProblems;
  final List<FinancialIntelligenceModelParityMetricResult>
  supportingParityMetrics;
  final List<FinancialIntelligenceRecommendationEvidence> evidence;
  final bool isDiagnosticsOnly;
}

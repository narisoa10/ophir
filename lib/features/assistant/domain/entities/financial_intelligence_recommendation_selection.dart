import 'financial_intelligence_decision_option.dart';
import 'financial_intelligence_recommendation_selection_reason.dart';

final class FinancialIntelligenceRecommendationSelection {
  FinancialIntelligenceRecommendationSelection({
    required this.selectedOption,
    required List<FinancialIntelligenceDecisionOption> rejectedOptions,
    required this.selectionReason,
    required this.isDiagnosticsOnly,
  }) : rejectedOptions = List.unmodifiable(rejectedOptions);

  final FinancialIntelligenceDecisionOption? selectedOption;
  final List<FinancialIntelligenceDecisionOption> rejectedOptions;
  final FinancialIntelligenceRecommendationSelectionReason selectionReason;
  final bool isDiagnosticsOnly;
}

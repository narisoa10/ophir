import 'financial_intelligence_decision_option.dart';
import 'financial_intelligence_recommendation_selection.dart';
import 'financial_intelligence_recommendation_selection_reason.dart';

final class FinancialIntelligenceRecommendationSelectionSnapshot {
  const FinancialIntelligenceRecommendationSelectionSnapshot({
    required this.selection,
  });

  final FinancialIntelligenceRecommendationSelection selection;

  FinancialIntelligenceDecisionOption? get selectedOption {
    return selection.selectedOption;
  }

  List<FinancialIntelligenceDecisionOption> get rejectedOptions {
    return selection.rejectedOptions;
  }

  FinancialIntelligenceRecommendationSelectionReason get selectionReason {
    return selection.selectionReason;
  }

  bool get isDiagnosticsOnly {
    return selection.isDiagnosticsOnly;
  }
}

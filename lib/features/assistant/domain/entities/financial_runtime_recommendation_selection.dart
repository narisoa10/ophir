import 'financial_explanation.dart';
import 'financial_recommendation.dart';
import 'financial_recommendation_comparison_read_model.dart';
import 'financial_runtime_recommendation_mode.dart';
import 'financial_runtime_recommendation_source.dart';

final class FinancialRuntimeRecommendationSelection {
  const FinancialRuntimeRecommendationSelection({
    required this.mode,
    required this.source,
    required this.recommendation,
    required this.comparison,
    this.explanation,
  });

  final FinancialRuntimeRecommendationMode mode;
  final FinancialRuntimeRecommendationSource source;
  final FinancialRecommendation? recommendation;
  final FinancialRecommendationComparisonReadModel? comparison;
  final FinancialExplanation? explanation;

  bool get usesIntelligenceRuntime {
    return source == FinancialRuntimeRecommendationSource.intelligenceAllowlist;
  }
}

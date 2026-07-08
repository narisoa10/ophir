import 'financial_intelligence_recommendation.dart';
import 'financial_intelligence_recommendation_type.dart';

final class FinancialIntelligenceRecommendationDiagnosticsSnapshot {
  FinancialIntelligenceRecommendationDiagnosticsSnapshot({
    required List<FinancialIntelligenceRecommendation> recommendations,
  }) : recommendations = List.unmodifiable(recommendations);

  final List<FinancialIntelligenceRecommendation> recommendations;

  List<FinancialIntelligenceRecommendation> recommendationsFor(
    FinancialIntelligenceRecommendationType type,
  ) {
    return recommendations
        .where((recommendation) => recommendation.type == type)
        .toList(growable: false);
  }

  bool hasRecommendation(FinancialIntelligenceRecommendationType type) {
    return recommendations.any((recommendation) => recommendation.type == type);
  }
}

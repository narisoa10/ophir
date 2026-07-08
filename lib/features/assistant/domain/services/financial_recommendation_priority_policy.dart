import '../entities/financial_recommendation_evaluation.dart';
import '../entities/financial_recommendation_priority.dart';

final class FinancialRecommendationPriorityPolicy {
  const FinancialRecommendationPriorityPolicy();

  FinancialRecommendationPriority priorityFor(
    FinancialRecommendationEvaluation evaluation,
  ) {
    if (evaluation.urgency >= 3 && evaluation.expectedImpact >= 4) {
      return FinancialRecommendationPriority.high;
    }
    if (evaluation.urgency >= 2 || evaluation.expectedImpact >= 3) {
      return FinancialRecommendationPriority.medium;
    }
    return FinancialRecommendationPriority.low;
  }
}

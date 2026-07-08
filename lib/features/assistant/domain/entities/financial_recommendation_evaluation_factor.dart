import 'financial_recommendation_factor_direction.dart';
import 'financial_recommendation_factor_type.dart';

final class FinancialRecommendationEvaluationFactor {
  const FinancialRecommendationEvaluationFactor({
    required this.factorType,
    required this.direction,
    required this.value,
  });

  final FinancialRecommendationFactorType factorType;
  final FinancialRecommendationFactorDirection direction;
  final int value;
}

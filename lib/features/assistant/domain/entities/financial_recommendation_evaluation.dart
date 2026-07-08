import 'financial_decision_option_type.dart';
import 'financial_recommendation_evaluation_factor.dart';
import 'financial_recommendation_reversibility.dart';

final class FinancialRecommendationEvaluation {
  const FinancialRecommendationEvaluation({
    required this.optionId,
    required this.optionType,
    required this.expectedImpact,
    required this.cost,
    required this.risk,
    required this.applicability,
    required this.confidence,
    required this.urgency,
    required this.reversibility,
    required this.horizon,
    required this.mayWorsenProblemCount,
    required this.factors,
  });

  final String optionId;
  final FinancialDecisionOptionType optionType;
  final int expectedImpact;
  final int cost;
  final int risk;
  final int applicability;
  final int confidence;
  final int urgency;
  final FinancialRecommendationReversibility reversibility;
  final int horizon;
  final int mayWorsenProblemCount;
  final List<FinancialRecommendationEvaluationFactor> factors;
}

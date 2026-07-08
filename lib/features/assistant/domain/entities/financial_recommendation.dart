import 'financial_decision_option.dart';
import 'financial_decision_option_type.dart';
import 'financial_rejected_alternative.dart';
import 'financial_recommendation_confidence.dart';
import 'financial_recommendation_evaluation.dart';
import 'financial_recommendation_evidence.dart';
import 'financial_recommendation_metadata.dart';
import 'financial_recommendation_priority.dart';
import 'financial_recommendation_status.dart';

final class FinancialRecommendation {
  const FinancialRecommendation({
    required this.recommendationId,
    required this.selectedOption,
    required this.selectedOptionId,
    required this.selectedOptionType,
    required this.status,
    required this.priority,
    required this.confidence,
    required this.evaluation,
    required this.rejectedAlternatives,
    required this.evidence,
    required this.metadata,
  });

  final String recommendationId;
  final FinancialDecisionOption selectedOption;
  final String selectedOptionId;
  final FinancialDecisionOptionType selectedOptionType;
  final FinancialRecommendationStatus status;
  final FinancialRecommendationPriority priority;
  final FinancialRecommendationConfidence confidence;
  final FinancialRecommendationEvaluation evaluation;
  final List<FinancialRejectedAlternative> rejectedAlternatives;
  final FinancialRecommendationEvidence evidence;
  final FinancialRecommendationMetadata metadata;
}

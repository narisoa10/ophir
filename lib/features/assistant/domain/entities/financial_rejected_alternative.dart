import 'financial_decision_option_type.dart';
import 'financial_rejected_alternative_reason.dart';
import 'financial_recommendation_evidence.dart';

final class FinancialRejectedAlternative {
  const FinancialRejectedAlternative({
    required this.optionId,
    required this.optionType,
    required this.reasonCodes,
    required this.evidence,
  });

  final String optionId;
  final FinancialDecisionOptionType optionType;
  final List<FinancialRejectedAlternativeReason> reasonCodes;
  final FinancialRecommendationEvidence evidence;
}

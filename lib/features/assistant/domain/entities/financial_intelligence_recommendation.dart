import 'financial_intelligence_problem_type.dart';
import 'financial_intelligence_recommendation_type.dart';
import 'financial_model_period.dart';

final class FinancialIntelligenceRecommendation {
  FinancialIntelligenceRecommendation({
    required this.recommendationId,
    required this.type,
    required this.period,
    required List<String> sourceProblemIds,
    required List<FinancialIntelligenceProblemType> sourceProblemTypes,
    required this.isPositiveSignal,
    required this.isWarning,
    required this.isDiagnosticsOnly,
  }) : sourceProblemIds = List.unmodifiable(sourceProblemIds),
       sourceProblemTypes = List.unmodifiable(sourceProblemTypes);

  final String recommendationId;
  final FinancialIntelligenceRecommendationType type;
  final FinancialModelPeriod period;
  final List<String> sourceProblemIds;
  final List<FinancialIntelligenceProblemType> sourceProblemTypes;
  final bool isPositiveSignal;
  final bool isWarning;
  final bool isDiagnosticsOnly;
}

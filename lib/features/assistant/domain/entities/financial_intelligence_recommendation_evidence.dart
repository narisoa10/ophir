import 'financial_intelligence_deviation_type.dart';
import 'financial_intelligence_model_parity_metric.dart';
import 'financial_intelligence_problem_type.dart';

final class FinancialIntelligenceRecommendationEvidence {
  FinancialIntelligenceRecommendationEvidence({
    required this.evidenceId,
    required this.sourceOptionId,
    required List<String> sourceProblemIds,
    required List<FinancialIntelligenceProblemType> sourceProblemTypes,
    required List<String> sourceDeviationIds,
    required List<FinancialIntelligenceDeviationType> sourceDeviationTypes,
    required List<FinancialIntelligenceModelParityMetric> parityMetrics,
    required this.isDiagnosticsOnly,
  }) : sourceProblemIds = List.unmodifiable(sourceProblemIds),
       sourceProblemTypes = List.unmodifiable(sourceProblemTypes),
       sourceDeviationIds = List.unmodifiable(sourceDeviationIds),
       sourceDeviationTypes = List.unmodifiable(sourceDeviationTypes),
       parityMetrics = List.unmodifiable(parityMetrics);

  final String evidenceId;
  final String sourceOptionId;
  final List<String> sourceProblemIds;
  final List<FinancialIntelligenceProblemType> sourceProblemTypes;
  final List<String> sourceDeviationIds;
  final List<FinancialIntelligenceDeviationType> sourceDeviationTypes;
  final List<FinancialIntelligenceModelParityMetric> parityMetrics;
  final bool isDiagnosticsOnly;
}

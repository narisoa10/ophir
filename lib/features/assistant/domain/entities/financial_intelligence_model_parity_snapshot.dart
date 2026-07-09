import 'financial_intelligence_model_parity_metric.dart';
import 'financial_intelligence_model_parity_metric_result.dart';

final class FinancialIntelligenceModelParitySnapshot {
  FinancialIntelligenceModelParitySnapshot({
    required Map<FinancialIntelligenceModelParityMetric, double?>
    legacyModelValues,
    required Map<FinancialIntelligenceModelParityMetric, double?>
    intelligenceModelValues,
    required List<FinancialIntelligenceModelParityMetricResult> metricResults,
    required List<FinancialIntelligenceModelParityMetricResult> matchedMetrics,
    required List<FinancialIntelligenceModelParityMetricResult> missingMetrics,
    required List<FinancialIntelligenceModelParityMetricResult>
    intentionallyDivergentMetrics,
  }) : legacyModelValues = Map.unmodifiable(legacyModelValues),
       intelligenceModelValues = Map.unmodifiable(intelligenceModelValues),
       metricResults = List.unmodifiable(metricResults),
       matchedMetrics = List.unmodifiable(matchedMetrics),
       missingMetrics = List.unmodifiable(missingMetrics),
       intentionallyDivergentMetrics = List.unmodifiable(
         intentionallyDivergentMetrics,
       );

  final Map<FinancialIntelligenceModelParityMetric, double?> legacyModelValues;
  final Map<FinancialIntelligenceModelParityMetric, double?>
  intelligenceModelValues;
  final List<FinancialIntelligenceModelParityMetricResult> metricResults;
  final List<FinancialIntelligenceModelParityMetricResult> matchedMetrics;
  final List<FinancialIntelligenceModelParityMetricResult> missingMetrics;
  final List<FinancialIntelligenceModelParityMetricResult>
  intentionallyDivergentMetrics;

  FinancialIntelligenceModelParityMetricResult resultFor(
    FinancialIntelligenceModelParityMetric metric,
  ) {
    return metricResults.singleWhere((result) => result.metric == metric);
  }
}

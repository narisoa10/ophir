import 'financial_intelligence_model_parity_metric.dart';
import 'financial_intelligence_model_parity_status.dart';

final class FinancialIntelligenceModelParityMetricResult {
  const FinancialIntelligenceModelParityMetricResult({
    required this.metric,
    required this.status,
    required this.legacyValue,
    required this.intelligenceValue,
  });

  final FinancialIntelligenceModelParityMetric metric;
  final FinancialIntelligenceModelParityStatus status;
  final double? legacyValue;
  final double? intelligenceValue;
}

import 'financial_model_confidence.dart';
import 'financial_model_evidence.dart';
import 'financial_model_limitation.dart';
import 'financial_model_metadata.dart';
import 'financial_model_period.dart';
import 'financial_model_status.dart';
import 'financial_model_type.dart';
import 'financial_model_unit.dart';

final class FinancialModelResult {
  const FinancialModelResult({
    required this.modelId,
    required this.modelType,
    required this.status,
    required this.value,
    required this.unit,
    required this.period,
    required this.currencyCode,
    required this.dataConfidence,
    required this.modelConfidence,
    required this.evidence,
    required this.assumptions,
    required this.limitations,
    required this.inputCoverage,
    required this.metadata,
    required this.breakdown,
  });

  final String modelId;
  final FinancialModelType modelType;
  final FinancialModelStatus status;
  final double? value;
  final FinancialModelUnit unit;
  final FinancialModelPeriod period;
  final String? currencyCode;
  final FinancialModelConfidence dataConfidence;
  final FinancialModelConfidence modelConfidence;
  final FinancialModelEvidence evidence;
  final List<String> assumptions;
  final List<FinancialModelLimitation> limitations;
  final double inputCoverage;
  final FinancialModelMetadata metadata;
  final List<FinancialModelResult> breakdown;
}

import 'financial_deviation_confidence.dart';
import 'financial_deviation_evidence.dart';
import 'financial_deviation_expected_value.dart';
import 'financial_deviation_limitation.dart';
import 'financial_deviation_metadata.dart';
import 'financial_deviation_severity.dart';
import 'financial_deviation_status.dart';
import 'financial_deviation_type.dart';
import 'financial_model_period.dart';
import 'financial_model_unit.dart';

final class FinancialDeviation {
  const FinancialDeviation({
    required this.deviationId,
    required this.deviationType,
    required this.status,
    required this.severity,
    required this.actualValue,
    required this.expectedValue,
    required this.deviationAmount,
    required this.unit,
    required this.period,
    required this.confidence,
    required this.evidence,
    required this.limitations,
    required this.metadata,
  });

  final String deviationId;
  final FinancialDeviationType deviationType;
  final FinancialDeviationStatus status;
  final FinancialDeviationSeverity severity;
  final double actualValue;
  final FinancialDeviationExpectedValue expectedValue;
  final double deviationAmount;
  final FinancialModelUnit unit;
  final FinancialModelPeriod period;
  final FinancialDeviationConfidence confidence;
  final FinancialDeviationEvidence evidence;
  final List<FinancialDeviationLimitation> limitations;
  final FinancialDeviationMetadata metadata;
}

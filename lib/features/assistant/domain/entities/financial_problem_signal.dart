import 'financial_deviation_confidence.dart';
import 'financial_deviation_severity.dart';
import 'financial_deviation_type.dart';

final class FinancialProblemSignal {
  const FinancialProblemSignal({
    required this.deviationId,
    required this.deviationType,
    required this.severity,
    required this.confidence,
    required this.isPrimary,
  });

  final String deviationId;
  final FinancialDeviationType deviationType;
  final FinancialDeviationSeverity severity;
  final FinancialDeviationConfidence confidence;
  final bool isPrimary;
}

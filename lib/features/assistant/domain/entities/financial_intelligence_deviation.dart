import 'financial_deviation_severity.dart';
import 'financial_intelligence_deviation_type.dart';
import 'financial_intelligence_model_type.dart';
import 'financial_model_period.dart';
import 'financial_model_unit.dart';

final class FinancialIntelligenceDeviation {
  FinancialIntelligenceDeviation({
    required this.deviationId,
    required this.type,
    required this.actualValue,
    required this.expectedValue,
    required this.deviationAmount,
    required this.unit,
    required this.period,
    required this.severity,
    required List<FinancialIntelligenceModelType> sourceModelTypes,
    required this.isWarning,
    required this.isDiagnosticsOnly,
  }) : sourceModelTypes = List.unmodifiable(sourceModelTypes);

  final String deviationId;
  final FinancialIntelligenceDeviationType type;
  final double actualValue;
  final double expectedValue;
  final double deviationAmount;
  final FinancialModelUnit unit;
  final FinancialModelPeriod period;
  final FinancialDeviationSeverity severity;
  final List<FinancialIntelligenceModelType> sourceModelTypes;
  final bool isWarning;
  final bool isDiagnosticsOnly;
}

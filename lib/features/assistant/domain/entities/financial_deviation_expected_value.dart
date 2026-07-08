import 'financial_model_unit.dart';

final class FinancialDeviationExpectedValue {
  const FinancialDeviationExpectedValue({
    required this.thresholdValue,
    required this.unit,
    required this.isUpperBound,
  });

  final double thresholdValue;
  final FinancialModelUnit unit;
  final bool isUpperBound;
}

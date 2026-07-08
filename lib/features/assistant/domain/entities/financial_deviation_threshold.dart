import 'financial_deviation_expected_value.dart';
import 'financial_deviation_type.dart';

final class FinancialDeviationThreshold {
  const FinancialDeviationThreshold({
    required this.id,
    required this.deviationType,
    required this.expectedValue,
  });

  final String id;
  final FinancialDeviationType deviationType;
  final FinancialDeviationExpectedValue expectedValue;
}

import '../entities/financial_deviation_severity.dart';

final class FinancialDeviationSeverityPolicy {
  const FinancialDeviationSeverityPolicy();

  static const double highRelativeDeviationBoundary = 0.5;
  static const double mediumRelativeDeviationBoundary = 0.2;

  FinancialDeviationSeverity severityFor({
    required double deviationAmount,
    required double thresholdValue,
  }) {
    final denominator = thresholdValue.abs();
    if (denominator == 0) {
      return deviationAmount.abs() > 0
          ? FinancialDeviationSeverity.high
          : FinancialDeviationSeverity.low;
    }

    final relativeDeviation = deviationAmount.abs() / denominator;
    if (relativeDeviation >= highRelativeDeviationBoundary) {
      return FinancialDeviationSeverity.high;
    }
    if (relativeDeviation >= mediumRelativeDeviationBoundary) {
      return FinancialDeviationSeverity.medium;
    }
    return FinancialDeviationSeverity.low;
  }
}

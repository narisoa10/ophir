import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_severity.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_problem_confidence.dart';
import '../entities/financial_problem_severity.dart';

final class FinancialProblemSeverityPolicy {
  const FinancialProblemSeverityPolicy();

  static const int lowSeverityScore = 1;
  static const int mediumSeverityScore = 2;
  static const int highSeverityScore = 3;
  static const int singleSupportingSignalBoost = 1;
  static const int multipleSupportingSignalBoost = 2;
  static const int outcomeSignalBoost = 1;

  FinancialProblemSeverity severityFor({
    required List<FinancialDeviation> requiredDeviations,
    required List<FinancialDeviation> supportingDeviations,
    required FinancialProblemConfidence confidence,
    required bool hasWeakDataQuality,
  }) {
    var score = requiredDeviations
        .map((deviation) => _score(deviation.severity))
        .reduce((value, element) => value > element ? value : element);

    if (supportingDeviations.length > 1) {
      score += multipleSupportingSignalBoost;
    } else if (supportingDeviations.length == 1) {
      score += singleSupportingSignalBoost;
    }

    if ([
      ...requiredDeviations,
      ...supportingDeviations,
    ].any(_isOutcomeSignal)) {
      score += outcomeSignalBoost;
    }

    if (hasWeakDataQuality || confidence == FinancialProblemConfidence.low) {
      score = score > mediumSeverityScore ? mediumSeverityScore : score;
    }

    if (score >= highSeverityScore) {
      return FinancialProblemSeverity.high;
    }
    if (score >= mediumSeverityScore) {
      return FinancialProblemSeverity.medium;
    }
    return FinancialProblemSeverity.low;
  }

  int _score(FinancialDeviationSeverity severity) {
    return switch (severity) {
      FinancialDeviationSeverity.high => highSeverityScore,
      FinancialDeviationSeverity.medium => mediumSeverityScore,
      FinancialDeviationSeverity.low => lowSeverityScore,
    };
  }

  bool _isOutcomeSignal(FinancialDeviation deviation) {
    return switch (deviation.deviationType) {
      FinancialDeviationType.negativeNetCashFlow ||
      FinancialDeviationType.lowSavingsRate => true,
      _ => false,
    };
  }
}

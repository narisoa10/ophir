import '../entities/financial_recommendation_evaluation.dart';
import '../entities/financial_recommendation_reversibility.dart';

final class FinancialRecommendationSelectionPolicy {
  const FinancialRecommendationSelectionPolicy();

  FinancialRecommendationEvaluation select(
    List<FinancialRecommendationEvaluation> evaluations,
  ) {
    final sorted = [...evaluations]..sort(_compare);
    return sorted.first;
  }

  int compare(
    FinancialRecommendationEvaluation left,
    FinancialRecommendationEvaluation right,
  ) {
    return _compare(left, right);
  }

  int _compare(
    FinancialRecommendationEvaluation left,
    FinancialRecommendationEvaluation right,
  ) {
    return _compareValues([
      _desc(left.applicability, right.applicability),
      _desc(left.urgency, right.urgency),
      _desc(left.expectedImpact, right.expectedImpact),
      _desc(left.confidence, right.confidence),
      _asc(left.risk, right.risk),
      _asc(left.cost, right.cost),
      _desc(
        _reversibilityValue(left.reversibility),
        _reversibilityValue(right.reversibility),
      ),
      _desc(left.horizon, right.horizon),
      _asc(left.mayWorsenProblemCount, right.mayWorsenProblemCount),
      left.optionType.index.compareTo(right.optionType.index),
      left.optionId.compareTo(right.optionId),
    ]);
  }

  int _compareValues(List<int> values) {
    for (final value in values) {
      if (value != 0) {
        return value;
      }
    }
    return 0;
  }

  int _desc(int left, int right) {
    return right.compareTo(left);
  }

  int _asc(int left, int right) {
    return left.compareTo(right);
  }

  int _reversibilityValue(FinancialRecommendationReversibility reversibility) {
    return switch (reversibility) {
      FinancialRecommendationReversibility.high => 3,
      FinancialRecommendationReversibility.medium => 2,
      FinancialRecommendationReversibility.low => 1,
    };
  }
}

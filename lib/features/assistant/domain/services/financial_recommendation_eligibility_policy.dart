import '../entities/financial_decision_option.dart';
import '../entities/financial_decision_option_applicability.dart';

final class FinancialRecommendationEligibilityPolicy {
  const FinancialRecommendationEligibilityPolicy();

  List<FinancialDecisionOption> executableOptions(
    List<FinancialDecisionOption> options,
  ) {
    final hasApplicable = options.any(
      (option) =>
          option.applicability ==
          FinancialDecisionOptionApplicability.applicable,
    );

    return List.unmodifiable(
      options.where((option) {
        if (option.applicability ==
            FinancialDecisionOptionApplicability.applicable) {
          return true;
        }
        if (hasApplicable) {
          return false;
        }
        return option.applicability ==
            FinancialDecisionOptionApplicability.conditional;
      }),
    );
  }
}

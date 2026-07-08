import 'financial_problem_type.dart';
import 'financial_decision_option_risk_level.dart';

final class FinancialDecisionOptionRisk {
  const FinancialDecisionOptionRisk({
    required this.level,
    required this.mayWorsenProblemTypes,
  });

  final FinancialDecisionOptionRiskLevel level;
  final List<FinancialProblemType> mayWorsenProblemTypes;
}

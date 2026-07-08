import 'financial_decision_option_cost_level.dart';

final class FinancialDecisionOptionCost {
  const FinancialDecisionOptionCost({
    required this.effort,
    required this.timeCost,
    required this.financialCost,
  });

  final FinancialDecisionOptionCostLevel effort;
  final FinancialDecisionOptionCostLevel timeCost;
  final FinancialDecisionOptionCostLevel financialCost;
}

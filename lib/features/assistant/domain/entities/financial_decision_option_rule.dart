import 'financial_problem_type.dart';
import 'financial_decision_expected_model_change.dart';
import 'financial_decision_option_condition.dart';
import 'financial_decision_option_cost.dart';
import 'financial_decision_option_effect_horizon.dart';
import 'financial_decision_option_limitation.dart';
import 'financial_decision_option_risk.dart';
import 'financial_decision_option_type.dart';
import 'financial_decision_target.dart';

final class FinancialDecisionOptionRule {
  const FinancialDecisionOptionRule({
    required this.ruleId,
    required this.optionType,
    required this.solvesProblemTypes,
    required this.mayWorsenProblemTypes,
    required this.targets,
    required this.expectedModelChanges,
    required this.cost,
    required this.risk,
    required this.conditions,
    required this.limitations,
    required this.effectHorizon,
  });

  final String ruleId;
  final FinancialDecisionOptionType optionType;
  final List<FinancialProblemType> solvesProblemTypes;
  final List<FinancialProblemType> mayWorsenProblemTypes;
  final List<FinancialDecisionTarget> targets;
  final List<FinancialDecisionExpectedModelChange> expectedModelChanges;
  final FinancialDecisionOptionCost cost;
  final FinancialDecisionOptionRisk risk;
  final List<FinancialDecisionOptionCondition> conditions;
  final List<FinancialDecisionOptionLimitation> limitations;
  final FinancialDecisionOptionEffectHorizon effectHorizon;
}

import 'financial_problem_type.dart';
import 'financial_decision_expected_model_change.dart';
import 'financial_decision_objective.dart';
import 'financial_decision_option_applicability.dart';
import 'financial_decision_option_availability_reason.dart';
import 'financial_decision_option_condition.dart';
import 'financial_decision_option_cost.dart';
import 'financial_decision_option_effect_horizon.dart';
import 'financial_decision_option_evidence.dart';
import 'financial_decision_option_impact.dart';
import 'financial_decision_option_limitation.dart';
import 'financial_decision_option_metadata.dart';
import 'financial_decision_option_risk.dart';
import 'financial_decision_option_status.dart';
import 'financial_decision_option_type.dart';
import 'financial_decision_target.dart';

final class FinancialDecisionOption {
  const FinancialDecisionOption({
    required this.optionId,
    required this.optionType,
    required this.status,
    required this.applicability,
    required this.linkedProblemIds,
    required this.solvesProblemTypes,
    required this.mayWorsenProblemTypes,
    required this.objectives,
    required this.targets,
    required this.expectedModelChanges,
    required this.impact,
    required this.cost,
    required this.risk,
    required this.conditions,
    required this.limitations,
    required this.availabilityReasons,
    required this.evidence,
    required this.metadata,
    required this.effectHorizon,
  });

  final String optionId;
  final FinancialDecisionOptionType optionType;
  final FinancialDecisionOptionStatus status;
  final FinancialDecisionOptionApplicability applicability;
  final List<String> linkedProblemIds;
  final List<FinancialProblemType> solvesProblemTypes;
  final List<FinancialProblemType> mayWorsenProblemTypes;
  final List<FinancialDecisionObjective> objectives;
  final List<FinancialDecisionTarget> targets;
  final List<FinancialDecisionExpectedModelChange> expectedModelChanges;
  final FinancialDecisionOptionImpact impact;
  final FinancialDecisionOptionCost cost;
  final FinancialDecisionOptionRisk risk;
  final List<FinancialDecisionOptionCondition> conditions;
  final List<FinancialDecisionOptionLimitation> limitations;
  final List<FinancialDecisionOptionAvailabilityReason> availabilityReasons;
  final FinancialDecisionOptionEvidence evidence;
  final FinancialDecisionOptionMetadata metadata;
  final FinancialDecisionOptionEffectHorizon effectHorizon;
}

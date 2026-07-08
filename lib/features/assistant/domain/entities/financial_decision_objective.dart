import 'financial_problem_type.dart';
import 'financial_decision_objective_type.dart';

final class FinancialDecisionObjective {
  const FinancialDecisionObjective({
    required this.objectiveId,
    required this.objectiveType,
    required this.sourceProblemId,
    required this.sourceProblemType,
  });

  final String objectiveId;
  final FinancialDecisionObjectiveType objectiveType;
  final String sourceProblemId;
  final FinancialProblemType sourceProblemType;
}

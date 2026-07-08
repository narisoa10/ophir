import '../entities/financial_decision_objective.dart';
import '../entities/financial_decision_objective_type.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_type.dart';

final class FinancialDecisionObjectiveService {
  const FinancialDecisionObjectiveService();

  List<FinancialDecisionObjective> objectivesFor(
    List<FinancialProblem> problems,
  ) {
    return List.unmodifiable(problems.map(_objectiveFor));
  }

  FinancialDecisionObjective _objectiveFor(FinancialProblem problem) {
    return FinancialDecisionObjective(
      objectiveId:
          'financial.decision.objective.'
          '${_typeFor(problem.problemType).name}.${problem.problemId}',
      objectiveType: _typeFor(problem.problemType),
      sourceProblemId: problem.problemId,
      sourceProblemType: problem.problemType,
    );
  }

  FinancialDecisionObjectiveType _typeFor(FinancialProblemType type) {
    return switch (type) {
      FinancialProblemType.cashFlowDeficit =>
        FinancialDecisionObjectiveType.restorePositiveCashFlow,
      FinancialProblemType.expensePressure =>
        FinancialDecisionObjectiveType.reduceExpensePressure,
      FinancialProblemType.weakSavingsCapacity =>
        FinancialDecisionObjectiveType.improveSavingsCapacity,
      FinancialProblemType.discretionarySpendingPressure =>
        FinancialDecisionObjectiveType.reduceDiscretionaryPressure,
      FinancialProblemType.essentialCostPressure =>
        FinancialDecisionObjectiveType.reduceEssentialCostPressure,
      FinancialProblemType.fixedCommitmentPressure =>
        FinancialDecisionObjectiveType.reduceFixedCommitmentPressure,
      FinancialProblemType.poorDataReliability =>
        FinancialDecisionObjectiveType.improveDataReliability,
    };
  }
}

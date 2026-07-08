import '../entities/financial_decision_objective.dart';
import '../entities/financial_decision_option.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_type.dart';
import 'financial_decision_option_catalog.dart';
import 'financial_decision_option_factory.dart';

final class SpendingDecisionOptionsService {
  const SpendingDecisionOptionsService({
    this.factory = const FinancialDecisionOptionFactory(),
  });

  final FinancialDecisionOptionFactory factory;

  List<FinancialDecisionOption> optionsFor({
    required List<FinancialProblem> problems,
    required List<FinancialDecisionObjective> objectives,
  }) {
    final linked = problems
        .where(
          (problem) =>
              problem.problemType == FinancialProblemType.expensePressure ||
              problem.problemType ==
                  FinancialProblemType.discretionarySpendingPressure ||
              problem.problemType == FinancialProblemType.essentialCostPressure,
        )
        .toList(growable: false);
    if (linked.isEmpty) {
      return const [];
    }
    return [
      for (final rule in [
        FinancialDecisionOptionCatalog.reviewExpenseStructure,
        FinancialDecisionOptionCatalog.reduceDiscretionarySpending,
        FinancialDecisionOptionCatalog.reduceRecurringCommitments,
        FinancialDecisionOptionCatalog.optimizeEssentialExpenses,
        FinancialDecisionOptionCatalog.reviewLargeExpense,
        FinancialDecisionOptionCatalog.adjustBudgetUnavailable,
        FinancialDecisionOptionCatalog.deferOptionalSpending,
        FinancialDecisionOptionCatalog.increaseIncome,
        FinancialDecisionOptionCatalog.restructureObligations,
        FinancialDecisionOptionCatalog.reviseFinancialStrategy,
        FinancialDecisionOptionCatalog.collectMoreData,
      ])
        factory.create(
          rule: rule,
          linkedProblems: linked
              .where(
                (problem) =>
                    rule.solvesProblemTypes.contains(problem.problemType),
              )
              .toList(growable: false),
          objectives: objectives,
        ),
    ].where((option) => option.linkedProblemIds.isNotEmpty).toList();
  }
}

import '../entities/financial_decision_objective.dart';
import '../entities/financial_decision_option.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_type.dart';
import 'financial_decision_option_catalog.dart';
import 'financial_decision_option_factory.dart';

final class SavingsDecisionOptionsService {
  const SavingsDecisionOptionsService({
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
              problem.problemType == FinancialProblemType.weakSavingsCapacity,
        )
        .toList(growable: false);
    if (linked.isEmpty) {
      return const [];
    }
    return [
      for (final rule in [
        FinancialDecisionOptionCatalog.increaseIncome,
        FinancialDecisionOptionCatalog.reduceDiscretionarySpending,
        FinancialDecisionOptionCatalog.reduceRecurringCommitments,
        FinancialDecisionOptionCatalog.buildSavingsCapacity,
        FinancialDecisionOptionCatalog.reviseFinancialStrategy,
        FinancialDecisionOptionCatalog.deferOptionalSpending,
        FinancialDecisionOptionCatalog.collectMoreData,
      ])
        factory.create(
          rule: rule,
          linkedProblems: linked,
          objectives: objectives,
        ),
    ];
  }
}

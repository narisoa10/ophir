import '../entities/financial_decision_objective.dart';
import '../entities/financial_decision_option.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_type.dart';
import 'financial_decision_option_catalog.dart';
import 'financial_decision_option_factory.dart';

final class CommitmentDecisionOptionsService {
  const CommitmentDecisionOptionsService({
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
              problem.problemType ==
              FinancialProblemType.fixedCommitmentPressure,
        )
        .toList(growable: false);
    if (linked.isEmpty) {
      return const [];
    }
    return [
      for (final rule in [
        FinancialDecisionOptionCatalog.reduceRecurringCommitments,
        FinancialDecisionOptionCatalog.confirmRecurringOperations,
        FinancialDecisionOptionCatalog.restructureObligations,
        FinancialDecisionOptionCatalog.increaseIncome,
        FinancialDecisionOptionCatalog.reviseFinancialStrategy,
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

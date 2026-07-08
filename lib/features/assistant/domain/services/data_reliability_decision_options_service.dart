import '../entities/financial_decision_objective.dart';
import '../entities/financial_decision_option.dart';
import '../entities/financial_decision_option_rule.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_confidence.dart';
import '../entities/financial_problem_type.dart';
import 'financial_decision_option_catalog.dart';
import 'financial_decision_option_factory.dart';

final class DataReliabilityDecisionOptionsService {
  const DataReliabilityDecisionOptionsService({
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
              problem.problemType == FinancialProblemType.poorDataReliability ||
              problem.confidence == FinancialProblemConfidence.low ||
              problem.confidence == FinancialProblemConfidence.none,
        )
        .toList(growable: false);
    if (linked.isEmpty) {
      return const [];
    }
    return [
      for (final rule in [
        FinancialDecisionOptionCatalog.improveCategorization,
        FinancialDecisionOptionCatalog.confirmRecurringOperations,
        FinancialDecisionOptionCatalog.collectMoreData,
        FinancialDecisionOptionCatalog.reviewLargeExpense,
        FinancialDecisionOptionCatalog.doNothingAndMonitor,
      ])
        factory.create(
          rule: rule,
          linkedProblems: _linkedProblemsForRule(rule, linked),
          objectives: objectives,
        ),
    ].where((option) => option.linkedProblemIds.isNotEmpty).toList();
  }

  List<FinancialProblem> _linkedProblemsForRule(
    FinancialDecisionOptionRule rule,
    List<FinancialProblem> linked,
  ) {
    return linked
        .where(
          (problem) =>
              rule.solvesProblemTypes.contains(problem.problemType) ||
              ((rule.optionType ==
                          FinancialDecisionOptionCatalog
                              .collectMoreData
                              .optionType ||
                      rule.optionType ==
                          FinancialDecisionOptionCatalog
                              .doNothingAndMonitor
                              .optionType) &&
                  (problem.confidence == FinancialProblemConfidence.low ||
                      problem.confidence == FinancialProblemConfidence.none)),
        )
        .toList(growable: false);
  }
}

import 'financial_intelligence_problem.dart';
import 'financial_intelligence_problem_type.dart';

final class FinancialIntelligenceProblemsSnapshot {
  FinancialIntelligenceProblemsSnapshot({
    required List<FinancialIntelligenceProblem> problems,
  }) : problems = List.unmodifiable(problems);

  final List<FinancialIntelligenceProblem> problems;

  List<FinancialIntelligenceProblem> problemsFor(
    FinancialIntelligenceProblemType type,
  ) {
    return problems
        .where((problem) => problem.type == type)
        .toList(growable: false);
  }

  bool hasProblem(FinancialIntelligenceProblemType type) {
    return problems.any((problem) => problem.type == type);
  }
}

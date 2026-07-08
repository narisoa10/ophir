import 'financial_problem.dart';
import 'financial_problem_type.dart';

final class FinancialProblemMergePolicy {
  const FinancialProblemMergePolicy();

  List<FinancialProblem> merge(List<FinancialProblem> candidates) {
    final byTypeAndPeriod = <String, FinancialProblem>{};
    for (final candidate in candidates) {
      byTypeAndPeriod[_problemKey(candidate)] = candidate;
    }

    final cashFlowPeriods = byTypeAndPeriod.values
        .where(
          (problem) =>
              problem.problemType == FinancialProblemType.cashFlowDeficit,
        )
        .map(_periodKey)
        .toSet();
    byTypeAndPeriod.removeWhere(
      (_, problem) =>
          problem.problemType == FinancialProblemType.weakSavingsCapacity &&
          cashFlowPeriods.contains(_periodKey(problem)),
    );

    return List.unmodifiable(byTypeAndPeriod.values);
  }

  String _problemKey(FinancialProblem problem) {
    return '${problem.problemType.name}:${_periodKey(problem)}';
  }

  String _periodKey(FinancialProblem problem) {
    return '${problem.period.start.microsecondsSinceEpoch}:'
        '${problem.period.end.microsecondsSinceEpoch}';
  }
}

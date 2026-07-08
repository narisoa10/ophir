import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_status.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_merge_policy.dart';
import 'cash_flow_problem_service.dart';
import 'data_reliability_problem_service.dart';
import 'recurring_commitment_problem_service.dart';
import 'savings_problem_service.dart';
import 'spending_problem_service.dart';

final class FinancialProblemDetectionService {
  const FinancialProblemDetectionService({
    this.cashFlowProblemService = const CashFlowProblemService(),
    this.spendingProblemService = const SpendingProblemService(),
    this.savingsProblemService = const SavingsProblemService(),
    this.recurringCommitmentProblemService =
        const RecurringCommitmentProblemService(),
    this.dataReliabilityProblemService = const DataReliabilityProblemService(),
    this.mergePolicy = const FinancialProblemMergePolicy(),
  });

  final CashFlowProblemService cashFlowProblemService;
  final SpendingProblemService spendingProblemService;
  final SavingsProblemService savingsProblemService;
  final RecurringCommitmentProblemService recurringCommitmentProblemService;
  final DataReliabilityProblemService dataReliabilityProblemService;
  final FinancialProblemMergePolicy mergePolicy;

  List<FinancialProblem> detect(List<FinancialDeviation> deviations) {
    final calculated = deviations
        .where(
          (deviation) =>
              deviation.status == FinancialDeviationStatus.calculated,
        )
        .toList(growable: false);

    final problems = <FinancialProblem>[];
    for (final periodDeviations in _groupByPeriod(calculated).values) {
      problems.addAll(
        mergePolicy.merge([
          ...cashFlowProblemService.detect(periodDeviations),
          ...spendingProblemService.detect(periodDeviations),
          ...savingsProblemService.detect(periodDeviations),
          ...recurringCommitmentProblemService.detect(periodDeviations),
          ...dataReliabilityProblemService.detect(periodDeviations),
        ]),
      );
    }

    return List.unmodifiable(problems);
  }

  Map<String, List<FinancialDeviation>> _groupByPeriod(
    List<FinancialDeviation> deviations,
  ) {
    final groups = <String, List<FinancialDeviation>>{};
    for (final deviation in deviations) {
      final key = _periodKey(deviation);
      groups.putIfAbsent(key, () => []).add(deviation);
    }
    return groups;
  }

  String _periodKey(FinancialDeviation deviation) {
    return '${deviation.period.start.microsecondsSinceEpoch}:'
        '${deviation.period.end.microsecondsSinceEpoch}';
  }
}

import '../entities/financial_decision_option.dart';
import '../entities/financial_problem.dart';
import 'cash_flow_decision_options_service.dart';
import 'commitment_decision_options_service.dart';
import 'data_reliability_decision_options_service.dart';
import 'financial_decision_objective_service.dart';
import 'financial_decision_option_deduplication_policy.dart';
import 'savings_decision_options_service.dart';
import 'spending_decision_options_service.dart';

final class FinancialDecisionOptionsService {
  const FinancialDecisionOptionsService({
    this.objectiveService = const FinancialDecisionObjectiveService(),
    this.cashFlowDecisionOptionsService =
        const CashFlowDecisionOptionsService(),
    this.spendingDecisionOptionsService =
        const SpendingDecisionOptionsService(),
    this.savingsDecisionOptionsService = const SavingsDecisionOptionsService(),
    this.commitmentDecisionOptionsService =
        const CommitmentDecisionOptionsService(),
    this.dataReliabilityDecisionOptionsService =
        const DataReliabilityDecisionOptionsService(),
    this.deduplicationPolicy =
        const FinancialDecisionOptionDeduplicationPolicy(),
  });

  final FinancialDecisionObjectiveService objectiveService;
  final CashFlowDecisionOptionsService cashFlowDecisionOptionsService;
  final SpendingDecisionOptionsService spendingDecisionOptionsService;
  final SavingsDecisionOptionsService savingsDecisionOptionsService;
  final CommitmentDecisionOptionsService commitmentDecisionOptionsService;
  final DataReliabilityDecisionOptionsService
  dataReliabilityDecisionOptionsService;
  final FinancialDecisionOptionDeduplicationPolicy deduplicationPolicy;

  List<FinancialDecisionOption> generate(List<FinancialProblem> problems) {
    final objectives = objectiveService.objectivesFor(problems);
    final options = [
      ...cashFlowDecisionOptionsService.optionsFor(
        problems: problems,
        objectives: objectives,
      ),
      ...spendingDecisionOptionsService.optionsFor(
        problems: problems,
        objectives: objectives,
      ),
      ...savingsDecisionOptionsService.optionsFor(
        problems: problems,
        objectives: objectives,
      ),
      ...commitmentDecisionOptionsService.optionsFor(
        problems: problems,
        objectives: objectives,
      ),
      ...dataReliabilityDecisionOptionsService.optionsFor(
        problems: problems,
        objectives: objectives,
      ),
    ];

    return deduplicationPolicy.merge(options);
  }
}

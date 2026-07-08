import '../../../categories/domain/entities/category.dart';
import '../../../operations/domain/entities/operation.dart';
import '../entities/financial_behavior_compatibility_output.dart';
import '../entities/financial_model_period.dart';
import 'financial_behavior_facts_service.dart';
import 'financial_behavior_totals_service.dart';

final class FinancialBehaviorCompatibilityOrchestrator {
  const FinancialBehaviorCompatibilityOrchestrator({
    this.factsService = const FinancialBehaviorFactsService(),
    this.totalsService = const FinancialBehaviorTotalsService(),
  });

  final FinancialBehaviorFactsService factsService;
  final FinancialBehaviorTotalsService totalsService;

  FinancialBehaviorCompatibilityOutput build({
    required List<Operation> operations,
    required List<Category> categories,
    required FinancialModelPeriod period,
  }) {
    final snapshot = factsService.buildSnapshot(
      operations: operations,
      categories: categories,
    );

    return totalsService.outputFor(snapshot: snapshot, period: period);
  }
}

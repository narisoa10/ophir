import '../entities/financial_model_catalog.dart';
import '../entities/financial_model_period.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_facts_snapshot.dart';
import 'burn_rate_model_service.dart';
import 'cash_flow_model_service.dart';
import 'data_quality_model_service.dart';
import 'expense_ratio_model_service.dart';
import 'financial_model_result_builder.dart';
import 'recurring_commitment_model_service.dart';
import 'savings_rate_model_service.dart';

final class FinancialModelsService {
  const FinancialModelsService({
    this.cashFlowModelService = const CashFlowModelService(),
    this.expenseRatioModelService = const ExpenseRatioModelService(),
    this.savingsRateModelService = const SavingsRateModelService(),
    this.recurringCommitmentModelService =
        const RecurringCommitmentModelService(),
    this.burnRateModelService = const BurnRateModelService(),
    this.dataQualityModelService = const DataQualityModelService(),
    this.resultBuilder = const FinancialModelResultBuilder(),
  });

  final CashFlowModelService cashFlowModelService;
  final ExpenseRatioModelService expenseRatioModelService;
  final SavingsRateModelService savingsRateModelService;
  final RecurringCommitmentModelService recurringCommitmentModelService;
  final BurnRateModelService burnRateModelService;
  final DataQualityModelService dataQualityModelService;
  final FinancialModelResultBuilder resultBuilder;

  List<FinancialModelResult> calculateAll({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    return FinancialModelCatalog.definitions
        .map(
          (definition) => calculate(
            type: definition.type,
            snapshot: snapshot,
            period: period,
            calculatedAt: calculatedAt,
          ),
        )
        .toList(growable: false);
  }

  FinancialModelResult calculate({
    required FinancialModelType type,
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    if (FinancialModelCatalog.definitionFor(type) == null) {
      return resultBuilder.unsupportedResult(
        type: type,
        period: period,
        calculatedAt: calculatedAt,
        snapshot: snapshot,
      );
    }

    return switch (type) {
      FinancialModelType.incomeTotal => cashFlowModelService.incomeTotal(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
      ),
      FinancialModelType.expenseTotal => cashFlowModelService.expenseTotal(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
      ),
      FinancialModelType.netCashFlow => cashFlowModelService.netCashFlow(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
      ),
      FinancialModelType.cashFlowSummary =>
        cashFlowModelService.cashFlowSummary(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.expenseToIncomeRatio =>
        expenseRatioModelService.expenseToIncomeRatio(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.expenseAnalyticsGroupTotals =>
        expenseRatioModelService.expenseAnalyticsGroupTotals(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.essentialRatio =>
        expenseRatioModelService.essentialRatio(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.flexibleRatio =>
        expenseRatioModelService.flexibleRatio(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.lifestyleRatio =>
        expenseRatioModelService.lifestyleRatio(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.savingsRate => savingsRateModelService.savingsRate(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
      ),
      FinancialModelType.recurringCommitments =>
        recurringCommitmentModelService.recurringCommitments(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.monthlyFixedCostEstimate =>
        recurringCommitmentModelService.monthlyFixedCostEstimate(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.subscriptionLoadEstimate =>
        recurringCommitmentModelService.subscriptionLoadEstimate(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.variableCostEstimate =>
        recurringCommitmentModelService.variableCostEstimate(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.simpleBurnRate => burnRateModelService.simpleBurnRate(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
      ),
      FinancialModelType.dataQualityScore =>
        dataQualityModelService.dataQualityScore(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
        ),
      FinancialModelType.unsupported => resultBuilder.unsupportedResult(
        type: type,
        period: period,
        calculatedAt: calculatedAt,
        snapshot: snapshot,
      ),
    };
  }
}

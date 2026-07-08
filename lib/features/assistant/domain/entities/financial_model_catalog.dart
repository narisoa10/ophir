import 'financial_model_definition.dart';
import 'financial_model_type.dart';
import 'financial_model_unit.dart';

final class FinancialModelCatalog {
  const FinancialModelCatalog._();

  static const incomeTotal = FinancialModelDefinition(
    id: 'financial.model.incomeTotal',
    type: FinancialModelType.incomeTotal,
    unit: FinancialModelUnit.money,
  );
  static const expenseTotal = FinancialModelDefinition(
    id: 'financial.model.expenseTotal',
    type: FinancialModelType.expenseTotal,
    unit: FinancialModelUnit.money,
  );
  static const netCashFlow = FinancialModelDefinition(
    id: 'financial.model.netCashFlow',
    type: FinancialModelType.netCashFlow,
    unit: FinancialModelUnit.money,
  );
  static const cashFlowSummary = FinancialModelDefinition(
    id: 'financial.model.cashFlowSummary',
    type: FinancialModelType.cashFlowSummary,
    unit: FinancialModelUnit.money,
  );
  static const expenseToIncomeRatio = FinancialModelDefinition(
    id: 'financial.model.expenseToIncomeRatio',
    type: FinancialModelType.expenseToIncomeRatio,
    unit: FinancialModelUnit.ratio,
  );
  static const expenseAnalyticsGroupTotals = FinancialModelDefinition(
    id: 'financial.model.expenseAnalyticsGroupTotals',
    type: FinancialModelType.expenseAnalyticsGroupTotals,
    unit: FinancialModelUnit.money,
  );
  static const essentialRatio = FinancialModelDefinition(
    id: 'financial.model.essentialRatio',
    type: FinancialModelType.essentialRatio,
    unit: FinancialModelUnit.ratio,
  );
  static const flexibleRatio = FinancialModelDefinition(
    id: 'financial.model.flexibleRatio',
    type: FinancialModelType.flexibleRatio,
    unit: FinancialModelUnit.ratio,
  );
  static const lifestyleRatio = FinancialModelDefinition(
    id: 'financial.model.lifestyleRatio',
    type: FinancialModelType.lifestyleRatio,
    unit: FinancialModelUnit.ratio,
  );
  static const savingsRate = FinancialModelDefinition(
    id: 'financial.model.savingsRate',
    type: FinancialModelType.savingsRate,
    unit: FinancialModelUnit.ratio,
  );
  static const recurringCommitments = FinancialModelDefinition(
    id: 'financial.model.recurringCommitments',
    type: FinancialModelType.recurringCommitments,
    unit: FinancialModelUnit.money,
  );
  static const monthlyFixedCostEstimate = FinancialModelDefinition(
    id: 'financial.model.monthlyFixedCostEstimate',
    type: FinancialModelType.monthlyFixedCostEstimate,
    unit: FinancialModelUnit.money,
  );
  static const subscriptionLoadEstimate = FinancialModelDefinition(
    id: 'financial.model.subscriptionLoadEstimate',
    type: FinancialModelType.subscriptionLoadEstimate,
    unit: FinancialModelUnit.money,
  );
  static const variableCostEstimate = FinancialModelDefinition(
    id: 'financial.model.variableCostEstimate',
    type: FinancialModelType.variableCostEstimate,
    unit: FinancialModelUnit.money,
  );
  static const simpleBurnRate = FinancialModelDefinition(
    id: 'financial.model.simpleBurnRate',
    type: FinancialModelType.simpleBurnRate,
    unit: FinancialModelUnit.money,
  );
  static const dataQualityScore = FinancialModelDefinition(
    id: 'financial.model.dataQualityScore',
    type: FinancialModelType.dataQualityScore,
    unit: FinancialModelUnit.score,
  );

  static const definitions = <FinancialModelDefinition>[
    incomeTotal,
    expenseTotal,
    netCashFlow,
    cashFlowSummary,
    expenseToIncomeRatio,
    expenseAnalyticsGroupTotals,
    essentialRatio,
    flexibleRatio,
    lifestyleRatio,
    savingsRate,
    recurringCommitments,
    monthlyFixedCostEstimate,
    subscriptionLoadEstimate,
    variableCostEstimate,
    simpleBurnRate,
    dataQualityScore,
  ];

  static FinancialModelDefinition? definitionFor(FinancialModelType type) {
    for (final definition in definitions) {
      if (definition.type == type) {
        return definition;
      }
    }
    return null;
  }
}

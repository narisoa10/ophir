import 'financial_deviation_type.dart';
import 'financial_problem_impact.dart';
import 'financial_problem_rule.dart';
import 'financial_problem_type.dart';

final class FinancialProblemCatalog {
  const FinancialProblemCatalog._();

  static const cashFlowDeficit = FinancialProblemRule(
    id: 'financial.problem.rule.cashFlowDeficit',
    problemType: FinancialProblemType.cashFlowDeficit,
    requiredDeviationTypes: [FinancialDeviationType.negativeNetCashFlow],
    supportingDeviationTypes: [
      FinancialDeviationType.highExpenseToIncomeRatio,
      FinancialDeviationType.lowSavingsRate,
      FinancialDeviationType.highRecurringCommitmentLoad,
    ],
    impact: FinancialProblemImpact.cashFlow,
    minimumSupportingSignals: 0,
    allowsIsolatedMediumOrHighSignal: true,
  );

  static const expensePressure = FinancialProblemRule(
    id: 'financial.problem.rule.expensePressure',
    problemType: FinancialProblemType.expensePressure,
    requiredDeviationTypes: [FinancialDeviationType.highExpenseToIncomeRatio],
    supportingDeviationTypes: [
      FinancialDeviationType.negativeNetCashFlow,
      FinancialDeviationType.lowSavingsRate,
      FinancialDeviationType.highEssentialExpenseRatio,
      FinancialDeviationType.highFlexibleExpenseRatio,
      FinancialDeviationType.highLifestyleExpenseRatio,
    ],
    impact: FinancialProblemImpact.spendingFlexibility,
    minimumSupportingSignals: 1,
    allowsIsolatedMediumOrHighSignal: true,
  );

  static const weakSavingsCapacity = FinancialProblemRule(
    id: 'financial.problem.rule.weakSavingsCapacity',
    problemType: FinancialProblemType.weakSavingsCapacity,
    requiredDeviationTypes: [FinancialDeviationType.lowSavingsRate],
    supportingDeviationTypes: [
      FinancialDeviationType.negativeNetCashFlow,
      FinancialDeviationType.highExpenseToIncomeRatio,
      FinancialDeviationType.highRecurringCommitmentLoad,
    ],
    impact: FinancialProblemImpact.savingsCapacity,
    minimumSupportingSignals: 0,
    allowsIsolatedMediumOrHighSignal: true,
  );

  static const discretionarySpendingPressure = FinancialProblemRule(
    id: 'financial.problem.rule.discretionarySpendingPressure',
    problemType: FinancialProblemType.discretionarySpendingPressure,
    requiredDeviationTypes: [
      FinancialDeviationType.highFlexibleExpenseRatio,
      FinancialDeviationType.highLifestyleExpenseRatio,
    ],
    supportingDeviationTypes: [
      FinancialDeviationType.negativeNetCashFlow,
      FinancialDeviationType.lowSavingsRate,
      FinancialDeviationType.highExpenseToIncomeRatio,
    ],
    impact: FinancialProblemImpact.spendingFlexibility,
    minimumSupportingSignals: 1,
    allowsIsolatedMediumOrHighSignal: false,
  );

  static const essentialCostPressure = FinancialProblemRule(
    id: 'financial.problem.rule.essentialCostPressure',
    problemType: FinancialProblemType.essentialCostPressure,
    requiredDeviationTypes: [FinancialDeviationType.highEssentialExpenseRatio],
    supportingDeviationTypes: [
      FinancialDeviationType.negativeNetCashFlow,
      FinancialDeviationType.lowSavingsRate,
      FinancialDeviationType.highExpenseToIncomeRatio,
    ],
    impact: FinancialProblemImpact.spendingFlexibility,
    minimumSupportingSignals: 1,
    allowsIsolatedMediumOrHighSignal: false,
  );

  static const fixedCommitmentPressure = FinancialProblemRule(
    id: 'financial.problem.rule.fixedCommitmentPressure',
    problemType: FinancialProblemType.fixedCommitmentPressure,
    requiredDeviationTypes: [
      FinancialDeviationType.highRecurringCommitmentLoad,
    ],
    supportingDeviationTypes: [
      FinancialDeviationType.negativeNetCashFlow,
      FinancialDeviationType.lowSavingsRate,
      FinancialDeviationType.highExpenseToIncomeRatio,
    ],
    impact: FinancialProblemImpact.commitmentFlexibility,
    minimumSupportingSignals: 0,
    allowsIsolatedMediumOrHighSignal: true,
  );

  static const poorDataReliability = FinancialProblemRule(
    id: 'financial.problem.rule.poorDataReliability',
    problemType: FinancialProblemType.poorDataReliability,
    requiredDeviationTypes: [FinancialDeviationType.weakDataQuality],
    supportingDeviationTypes: [],
    impact: FinancialProblemImpact.dataReliability,
    minimumSupportingSignals: 0,
    allowsIsolatedMediumOrHighSignal: true,
  );

  static const rules = <FinancialProblemRule>[
    cashFlowDeficit,
    expensePressure,
    weakSavingsCapacity,
    discretionarySpendingPressure,
    essentialCostPressure,
    fixedCommitmentPressure,
    poorDataReliability,
  ];

  static FinancialProblemRule ruleFor(FinancialProblemType type) {
    return rules.singleWhere((rule) => rule.problemType == type);
  }
}

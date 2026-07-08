import '../entities/financial_deviation_expected_value.dart';
import '../entities/financial_deviation_threshold.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_model_unit.dart';

final class FinancialDeviationThresholdCatalog {
  const FinancialDeviationThresholdCatalog._();

  static const negativeNetCashFlow = FinancialDeviationThreshold(
    id: 'financial.deviation.threshold.negativeNetCashFlow',
    deviationType: FinancialDeviationType.negativeNetCashFlow,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 0,
      unit: FinancialModelUnit.money,
      isUpperBound: false,
    ),
  );

  static const highExpenseToIncomeRatio = FinancialDeviationThreshold(
    id: 'financial.deviation.threshold.highExpenseToIncomeRatio',
    deviationType: FinancialDeviationType.highExpenseToIncomeRatio,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 0.75,
      unit: FinancialModelUnit.ratio,
      isUpperBound: true,
    ),
  );

  static const lowSavingsRate = FinancialDeviationThreshold(
    id: 'financial.deviation.threshold.lowSavingsRate',
    deviationType: FinancialDeviationType.lowSavingsRate,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 0.10,
      unit: FinancialModelUnit.ratio,
      isUpperBound: false,
    ),
  );

  static const highEssentialExpenseRatio = FinancialDeviationThreshold(
    id: 'financial.deviation.threshold.highEssentialExpenseRatio',
    deviationType: FinancialDeviationType.highEssentialExpenseRatio,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 0.60,
      unit: FinancialModelUnit.ratio,
      isUpperBound: true,
    ),
  );

  static const highFlexibleExpenseRatio = FinancialDeviationThreshold(
    id: 'financial.deviation.threshold.highFlexibleExpenseRatio',
    deviationType: FinancialDeviationType.highFlexibleExpenseRatio,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 0.30,
      unit: FinancialModelUnit.ratio,
      isUpperBound: true,
    ),
  );

  static const highLifestyleExpenseRatio = FinancialDeviationThreshold(
    id: 'financial.deviation.threshold.highLifestyleExpenseRatio',
    deviationType: FinancialDeviationType.highLifestyleExpenseRatio,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 0.20,
      unit: FinancialModelUnit.ratio,
      isUpperBound: true,
    ),
  );

  static const highRecurringCommitmentLoad = FinancialDeviationThreshold(
    id: 'financial.deviation.threshold.highRecurringCommitmentLoad',
    deviationType: FinancialDeviationType.highRecurringCommitmentLoad,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 0.50,
      unit: FinancialModelUnit.ratio,
      isUpperBound: true,
    ),
  );

  static const weakDataQuality = FinancialDeviationThreshold(
    id: 'financial.deviation.threshold.weakDataQuality',
    deviationType: FinancialDeviationType.weakDataQuality,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 70,
      unit: FinancialModelUnit.score,
      isUpperBound: false,
    ),
  );

  static const thresholds = <FinancialDeviationThreshold>[
    negativeNetCashFlow,
    highExpenseToIncomeRatio,
    lowSavingsRate,
    highEssentialExpenseRatio,
    highFlexibleExpenseRatio,
    highLifestyleExpenseRatio,
    highRecurringCommitmentLoad,
    weakDataQuality,
  ];

  static FinancialDeviationThreshold thresholdFor(FinancialDeviationType type) {
    return thresholds.singleWhere(
      (threshold) => threshold.deviationType == type,
    );
  }
}

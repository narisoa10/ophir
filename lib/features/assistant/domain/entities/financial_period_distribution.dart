import 'financial_model_confidence.dart';
import 'financial_model_limitation.dart';
import 'financial_model_period.dart';
import 'financial_period_distribution_item.dart';

final class FinancialPeriodDistribution {
  const FinancialPeriodDistribution({
    required this.period,
    required this.currencyCode,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.netCashFlow,
    required this.items,
    required this.confidence,
    required this.evidenceModelIds,
    required this.limitations,
  });

  final FinancialModelPeriod period;
  final String? currencyCode;
  final double incomeTotal;
  final double expenseTotal;
  final double netCashFlow;
  final List<FinancialPeriodDistributionItem> items;
  final FinancialModelConfidence confidence;
  final List<String> evidenceModelIds;
  final List<FinancialModelLimitation> limitations;
}

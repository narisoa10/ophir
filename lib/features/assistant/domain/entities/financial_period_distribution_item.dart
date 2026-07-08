import 'financial_period_distribution_bucket.dart';
import 'financial_model_limitation.dart';

final class FinancialPeriodDistributionItem {
  const FinancialPeriodDistributionItem({
    required this.bucket,
    required this.amount,
    required this.percent,
    required this.limitations,
  });

  final FinancialPeriodDistributionBucket bucket;
  final double amount;
  final double percent;
  final List<FinancialModelLimitation> limitations;
}

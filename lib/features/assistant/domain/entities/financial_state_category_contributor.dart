import '../../../categories/domain/enums/category_financial_distribution_role.dart';
import '../../../categories/domain/enums/category_stable_key.dart';
import '../../../categories/domain/enums/spending_pattern.dart';

final class FinancialStateCategoryContributor {
  const FinancialStateCategoryContributor({
    required this.categoryId,
    required this.stableKey,
    required this.amount,
    required this.percentOfIncome,
    required this.percentOfExpenses,
    required this.distributionRole,
    required this.spendingPattern,
  });

  final String categoryId;
  final CategoryStableKey stableKey;
  final double amount;
  final double? percentOfIncome;
  final double? percentOfExpenses;
  final CategoryFinancialDistributionRole distributionRole;
  final SpendingPattern spendingPattern;
}

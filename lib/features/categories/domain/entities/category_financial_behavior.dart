import '../enums/category_financial_distribution_role.dart';
import 'category_intelligence_profile.dart';

final class CategoryFinancialBehavior {
  const CategoryFinancialBehavior({
    required this.profile,
    required this.isOrdinarySpending,
    required this.affectsSpendingAnalytics,
    required this.affectsSavingsRate,
    required this.affectsCashFlow,
    required this.distributionRole,
    required this.requiresTransactionContext,
    required this.isAssetBuilding,
    required this.isDebtReduction,
    required this.isCashMovement,
    required this.isDataAdjustment,
  });

  final CategoryIntelligenceProfile profile;
  final bool isOrdinarySpending;
  final bool affectsSpendingAnalytics;
  final bool affectsSavingsRate;
  final bool affectsCashFlow;
  final CategoryFinancialDistributionRole distributionRole;
  final bool requiresTransactionContext;
  final bool isAssetBuilding;
  final bool isDebtReduction;
  final bool isCashMovement;
  final bool isDataAdjustment;
}

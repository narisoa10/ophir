import '../entities/category.dart';
import '../entities/category_financial_behavior.dart';
import '../entities/category_intelligence_profile.dart';
import '../enums/category_financial_distribution_role.dart';
import '../enums/category_stable_key.dart';
import '../enums/financial_action_semantics.dart';
import '../enums/financial_impact.dart';
import '../enums/spending_pattern.dart';
import '../enums/spending_role.dart';
import 'category_intelligence_resolver.dart';

final class CategoryFinancialBehaviorPolicy {
  const CategoryFinancialBehaviorPolicy({
    CategoryIntelligenceResolver resolver =
        const CategoryIntelligenceResolver(),
  }) : _resolver = resolver;

  final CategoryIntelligenceResolver _resolver;

  CategoryFinancialBehavior? behaviorFor(Category category) {
    final profile = _resolver.profileFor(category);

    if (profile == null) {
      return null;
    }

    return behaviorForProfile(profile);
  }

  CategoryFinancialBehavior behaviorForProfile(
    CategoryIntelligenceProfile profile,
  ) {
    if (profile.stableKey == CategoryStableKey.expenseFinanceCurrencyExchange) {
      return _behavior(
        profile: profile,
        isOrdinarySpending: false,
        affectsSpendingAnalytics: false,
        affectsSavingsRate: false,
        affectsCashFlow: false,
        distributionRole: CategoryFinancialDistributionRole.contextDependent,
        requiresTransactionContext: true,
        isCashMovement: true,
      );
    }

    if (profile.stableKey == CategoryStableKey.expenseTransportationAutoLoan) {
      return _behavior(
        profile: profile,
        isOrdinarySpending: false,
        affectsSpendingAnalytics: false,
        affectsSavingsRate: false,
        affectsCashFlow: true,
        distributionRole: CategoryFinancialDistributionRole.contextDependent,
        requiresTransactionContext: true,
        isDebtReduction: true,
      );
    }

    return switch (profile.financialImpact) {
      FinancialImpact.ordinaryExpense => _ordinarySpending(profile),
      FinancialImpact.income => _behavior(
        profile: profile,
        distributionRole: CategoryFinancialDistributionRole.income,
        affectsSavingsRate: true,
        affectsCashFlow: true,
      ),
      FinancialImpact.assetBuilding => _behavior(
        profile: profile,
        distributionRole: CategoryFinancialDistributionRole.assetBuilding,
        affectsSavingsRate: true,
        affectsCashFlow: true,
        isAssetBuilding: true,
      ),
      FinancialImpact.debtReduction => _behavior(
        profile: profile,
        distributionRole: CategoryFinancialDistributionRole.debtReduction,
        affectsCashFlow: true,
        requiresTransactionContext: _requiresDebtTransactionContext(profile),
        isDebtReduction: true,
      ),
      FinancialImpact.cashMovement => _behavior(
        profile: profile,
        distributionRole: CategoryFinancialDistributionRole.cashMovement,
        requiresTransactionContext: true,
        isCashMovement: true,
      ),
      FinancialImpact.dataAdjustment => _behavior(
        profile: profile,
        distributionRole: CategoryFinancialDistributionRole.dataAdjustment,
        requiresTransactionContext: true,
        isDataAdjustment: true,
      ),
      FinancialImpact.unknown => _behavior(
        profile: profile,
        distributionRole: CategoryFinancialDistributionRole.contextDependent,
        requiresTransactionContext: true,
      ),
    };
  }

  CategoryFinancialBehavior _ordinarySpending(
    CategoryIntelligenceProfile profile,
  ) {
    return _behavior(
      profile: profile,
      isOrdinarySpending: true,
      affectsSpendingAnalytics: true,
      affectsSavingsRate: true,
      affectsCashFlow: true,
      distributionRole: _distributionRoleFor(profile.spendingRole),
      requiresTransactionContext:
          profile.spendingPattern ==
          SpendingPattern.requiresTransactionEvidence,
    );
  }

  CategoryFinancialDistributionRole _distributionRoleFor(SpendingRole role) {
    return switch (role) {
      SpendingRole.mandatory =>
        CategoryFinancialDistributionRole.mandatoryExpenses,
      SpendingRole.flexible =>
        CategoryFinancialDistributionRole.flexibleExpenses,
      SpendingRole.discretionary => CategoryFinancialDistributionRole.wants,
      SpendingRole.income => CategoryFinancialDistributionRole.income,
      SpendingRole.savingOrAssetBuilding =>
        CategoryFinancialDistributionRole.assetBuilding,
      SpendingRole.debtService =>
        CategoryFinancialDistributionRole.debtReduction,
      SpendingRole.nonBudgetFinancialAction || SpendingRole.unknown =>
        CategoryFinancialDistributionRole.contextDependent,
    };
  }

  bool _requiresDebtTransactionContext(CategoryIntelligenceProfile profile) {
    return switch (profile.financialActionSemantics) {
      FinancialActionSemantics.creditCardPayment ||
      FinancialActionSemantics.loanPayment => true,
      _ => false,
    };
  }

  CategoryFinancialBehavior _behavior({
    required CategoryIntelligenceProfile profile,
    required CategoryFinancialDistributionRole distributionRole,
    bool isOrdinarySpending = false,
    bool affectsSpendingAnalytics = false,
    bool affectsSavingsRate = false,
    bool affectsCashFlow = false,
    bool requiresTransactionContext = false,
    bool isAssetBuilding = false,
    bool isDebtReduction = false,
    bool isCashMovement = false,
    bool isDataAdjustment = false,
  }) {
    return CategoryFinancialBehavior(
      profile: profile,
      isOrdinarySpending: isOrdinarySpending,
      affectsSpendingAnalytics: affectsSpendingAnalytics,
      affectsSavingsRate: affectsSavingsRate,
      affectsCashFlow: affectsCashFlow,
      distributionRole: distributionRole,
      requiresTransactionContext: requiresTransactionContext,
      isAssetBuilding: isAssetBuilding,
      isDebtReduction: isDebtReduction,
      isCashMovement: isCashMovement,
      isDataAdjustment: isDataAdjustment,
    );
  }
}

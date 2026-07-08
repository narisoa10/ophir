import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/entities/category_financial_behavior.dart';
import 'package:ophir/features/categories/domain/entities/category_taxonomy.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_financial_distribution_role.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/services/category_financial_behavior_policy.dart';

void main() {
  const policy = CategoryFinancialBehaviorPolicy();

  group('CategoryFinancialBehaviorPolicy', () {
    test('all 147 stable keys have behavior', () {
      expect(CategoryTaxonomy.definitions.length, 147);

      for (final definition in CategoryTaxonomy.definitions) {
        final behavior = policy.behaviorFor(
          _category(type: definition.type, stableKey: definition.key.toJson()),
        );

        expect(behavior, isNotNull, reason: definition.key.toJson());
        expect(behavior!.profile.stableKey, definition.key);
        expect(behavior.profile.type, definition.type);
      }
    });

    test('normal spending affects spending analytics', () {
      final behaviors = CategoryTaxonomy.definitions
          .map(
            (definition) => policy.behaviorFor(
              _category(
                type: definition.type,
                stableKey: definition.key.toJson(),
              ),
            ),
          )
          .whereType();
      final normalSpending = behaviors.where(
        (behavior) => behavior.isOrdinarySpending,
      );

      expect(normalSpending, isNotEmpty);

      for (final behavior in normalSpending) {
        expect(behavior.affectsSpendingAnalytics, isTrue);
        expect(behavior.affectsSavingsRate, isTrue);
        expect(behavior.affectsCashFlow, isTrue);
        expect(
          behavior.distributionRole,
          isIn({
            CategoryFinancialDistributionRole.mandatoryExpenses,
            CategoryFinancialDistributionRole.flexibleExpenses,
            CategoryFinancialDistributionRole.wants,
          }),
        );
      }
    });

    test('special financial actions are not ordinary spending', () {
      for (final key in _specialFinancialActions) {
        final behavior = _behaviorForKey(policy, key);

        expect(behavior.isOrdinarySpending, isFalse);
        expect(behavior.affectsSpendingAnalytics, isFalse);
      }
    });

    test('asset building affects savings behavior', () {
      for (final key in _assetBuildingKeys) {
        final behavior = _behaviorForKey(policy, key);

        expect(behavior.isAssetBuilding, isTrue);
        expect(behavior.affectsSavingsRate, isTrue);
        expect(behavior.affectsCashFlow, isTrue);
        expect(behavior.affectsSpendingAnalytics, isFalse);
        expect(
          behavior.distributionRole,
          CategoryFinancialDistributionRole.assetBuilding,
        );
      }
    });

    test('debt repayment affects debt behavior', () {
      for (final key in _debtReductionKeys) {
        final behavior = _behaviorForKey(policy, key);

        expect(behavior.isDebtReduction, isTrue);
        expect(behavior.affectsSavingsRate, isFalse);
        expect(behavior.affectsCashFlow, isTrue);
        expect(behavior.affectsSpendingAnalytics, isFalse);
        expect(
          behavior.distributionRole,
          CategoryFinancialDistributionRole.debtReduction,
        );
      }
    });

    test('cash withdrawal is cash movement', () {
      final behavior = _behaviorForKey(
        policy,
        CategoryStableKey.expenseOtherCashWithdrawal,
      );

      expect(behavior.isCashMovement, isTrue);
      expect(behavior.isOrdinarySpending, isFalse);
      expect(behavior.affectsCashFlow, isFalse);
      expect(behavior.requiresTransactionContext, isTrue);
      expect(
        behavior.distributionRole,
        CategoryFinancialDistributionRole.cashMovement,
      );
    });

    test('adjustment is data adjustment', () {
      final behavior = _behaviorForKey(
        policy,
        CategoryStableKey.expenseOtherAdjustment,
      );

      expect(behavior.isDataAdjustment, isTrue);
      expect(behavior.isOrdinarySpending, isFalse);
      expect(behavior.affectsCashFlow, isFalse);
      expect(behavior.requiresTransactionContext, isTrue);
      expect(
        behavior.distributionRole,
        CategoryFinancialDistributionRole.dataAdjustment,
      );
    });

    test('currency exchange requires transaction context', () {
      final behavior = _behaviorForKey(
        policy,
        CategoryStableKey.expenseFinanceCurrencyExchange,
      );

      expect(behavior.requiresTransactionContext, isTrue);
      expect(behavior.isCashMovement, isTrue);
      expect(behavior.isOrdinarySpending, isFalse);
      expect(behavior.affectsSpendingAnalytics, isFalse);
      expect(
        behavior.distributionRole,
        CategoryFinancialDistributionRole.contextDependent,
      );
    });

    test('auto loan requires transaction context', () {
      final behavior = _behaviorForKey(
        policy,
        CategoryStableKey.expenseTransportationAutoLoan,
      );

      expect(behavior.requiresTransactionContext, isTrue);
      expect(behavior.isDebtReduction, isTrue);
      expect(behavior.isOrdinarySpending, isFalse);
      expect(behavior.affectsSpendingAnalytics, isFalse);
      expect(behavior.affectsCashFlow, isTrue);
      expect(
        behavior.distributionRole,
        CategoryFinancialDistributionRole.contextDependent,
      );
    });

    test('broad legacy category returns null unresolved behavior', () {
      final behavior = policy.behaviorFor(
        _category(nameKey: 'categoryUtilities'),
      );

      expect(behavior, isNull);
    });
  });
}

CategoryFinancialBehavior _behaviorForKey(
  CategoryFinancialBehaviorPolicy policy,
  CategoryStableKey key,
) {
  final definition = CategoryTaxonomy.definitionFor(key);

  expect(definition, isNotNull, reason: key.toJson());

  final behavior = policy.behaviorFor(
    _category(type: definition!.type, stableKey: key.toJson()),
  );

  expect(behavior, isNotNull, reason: key.toJson());
  return behavior!;
}

Category _category({
  CategoryType type = CategoryType.expense,
  String nameKey = 'categoryUnknownLegacy',
  String? stableKey,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: 'category-id',
    type: type,
    uiGroup: type == CategoryType.income
        ? CategoryUiGroup.income
        : CategoryUiGroup.dailyLife,
    analyticsGroup: type == CategoryType.income
        ? CategoryAnalyticsGroup.income
        : CategoryAnalyticsGroup.flexibleExpenses,
    nameKey: nameKey,
    iconKey: 'other',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey,
  );
}

const _assetBuildingKeys = {
  CategoryStableKey.expenseFinanceSavings,
  CategoryStableKey.expenseFinanceInvestments,
  CategoryStableKey.expenseFinanceTfsaContribution,
  CategoryStableKey.expenseFinanceRrspContribution,
  CategoryStableKey.expenseFinanceRespContribution,
  CategoryStableKey.expenseFinanceEmergencyFund,
};

const _debtReductionKeys = {
  CategoryStableKey.expenseFinanceDebtRepayment,
  CategoryStableKey.expenseFinanceCreditCardPayment,
  CategoryStableKey.expenseFinanceLoanPayment,
};

const _specialFinancialActions = {
  ..._assetBuildingKeys,
  ..._debtReductionKeys,
  CategoryStableKey.expenseOtherCashWithdrawal,
  CategoryStableKey.expenseOtherAdjustment,
};

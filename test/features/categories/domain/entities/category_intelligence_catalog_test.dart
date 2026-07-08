import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/categories/domain/entities/category_intelligence_catalog.dart';
import 'package:ophir/features/categories/domain/entities/category_taxonomy.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/financial_action_semantics.dart';
import 'package:ophir/features/categories/domain/enums/financial_impact.dart';
import 'package:ophir/features/categories/domain/enums/spending_role.dart';

void main() {
  group('CategoryIntelligenceCatalog', () {
    test('all taxonomy stable keys have exactly one profile', () {
      final taxonomyKeys = CategoryTaxonomy.definitions
          .map((definition) => definition.key)
          .toSet();

      expect(taxonomyKeys.length, 147);
      expect(CategoryIntelligenceCatalog.profiles.length, 147);
      expect(CategoryIntelligenceCatalog.profiles.keys.toSet(), taxonomyKeys);

      for (final key in taxonomyKeys) {
        final profile = CategoryIntelligenceCatalog.profileFor(key);

        expect(profile, isNotNull);
        expect(profile!.stableKey, key);
      }
    });

    test('expense and income profiles match taxonomy type', () {
      for (final definition in CategoryTaxonomy.definitions) {
        final profile = CategoryIntelligenceCatalog.profileFor(definition.key);

        expect(profile, isNotNull);
        expect(profile!.type, definition.type);
      }

      final profileTypes = CategoryIntelligenceCatalog.profiles.values
          .map((profile) => profile.type)
          .toSet();

      expect(profileTypes, {CategoryType.expense, CategoryType.income});
    });

    test('transfer is absent from intelligence catalog', () {
      final transferKeys = CategoryIntelligenceCatalog.profiles.keys.where(
        (key) => key.toJson().startsWith('transfer.'),
      );

      expect(transferKeys, isEmpty);
    });

    test('special financial actions are not ordinary spending', () {
      for (final key in _specialFinancialActions) {
        final profile = CategoryIntelligenceCatalog.profileFor(key);

        expect(profile, isNotNull);
        expect(profile!.isOrdinarySpending, isFalse);
        expect(profile.financialImpact, isNot(FinancialImpact.ordinaryExpense));
        expect(
          profile.financialActionSemantics,
          isNot(FinancialActionSemantics.none),
        );
      }
    });

    test('normal expense categories are ordinary spending', () {
      final normalExpenseKeys = CategoryTaxonomy.definitions
          .where((definition) => definition.type == CategoryType.expense)
          .map((definition) => definition.key)
          .where((key) => !_specialFinancialActions.contains(key));

      expect(normalExpenseKeys, isNotEmpty);

      for (final key in normalExpenseKeys) {
        final profile = CategoryIntelligenceCatalog.profileFor(key);

        expect(profile, isNotNull);
        expect(profile!.isOrdinarySpending, isTrue);
        expect(profile.financialImpact, FinancialImpact.ordinaryExpense);
        expect(profile.financialActionSemantics, FinancialActionSemantics.none);
      }
    });

    test('asset building financial actions use asset building semantics', () {
      final expectedActions = {
        CategoryStableKey.expenseFinanceSavings:
            FinancialActionSemantics.savingsContribution,
        CategoryStableKey.expenseFinanceInvestments:
            FinancialActionSemantics.investmentContribution,
        CategoryStableKey.expenseFinanceTfsaContribution:
            FinancialActionSemantics.tfsaContribution,
        CategoryStableKey.expenseFinanceRrspContribution:
            FinancialActionSemantics.rrspContribution,
        CategoryStableKey.expenseFinanceRespContribution:
            FinancialActionSemantics.respContribution,
        CategoryStableKey.expenseFinanceEmergencyFund:
            FinancialActionSemantics.emergencyFundContribution,
      };

      for (final entry in expectedActions.entries) {
        final profile = CategoryIntelligenceCatalog.profileFor(entry.key);

        expect(profile, isNotNull);
        expect(profile!.spendingRole, SpendingRole.savingOrAssetBuilding);
        expect(profile.financialImpact, FinancialImpact.assetBuilding);
        expect(profile.financialActionSemantics, entry.value);
      }
    });

    test('debt payment actions use debt and liability semantics', () {
      final expectedActions = {
        CategoryStableKey.expenseFinanceDebtRepayment:
            FinancialActionSemantics.debtRepayment,
        CategoryStableKey.expenseFinanceCreditCardPayment:
            FinancialActionSemantics.creditCardPayment,
        CategoryStableKey.expenseFinanceLoanPayment:
            FinancialActionSemantics.loanPayment,
      };

      for (final entry in expectedActions.entries) {
        final profile = CategoryIntelligenceCatalog.profileFor(entry.key);

        expect(profile, isNotNull);
        expect(profile!.spendingRole, SpendingRole.debtService);
        expect(profile.financialImpact, FinancialImpact.debtReduction);
        expect(profile.financialActionSemantics, entry.value);
      }
    });

    test('cash withdrawal and adjustment use non-budget semantics', () {
      final cashWithdrawal = CategoryIntelligenceCatalog.profileFor(
        CategoryStableKey.expenseOtherCashWithdrawal,
      );
      final adjustment = CategoryIntelligenceCatalog.profileFor(
        CategoryStableKey.expenseOtherAdjustment,
      );

      expect(cashWithdrawal, isNotNull);
      expect(
        cashWithdrawal!.spendingRole,
        SpendingRole.nonBudgetFinancialAction,
      );
      expect(cashWithdrawal.financialImpact, FinancialImpact.cashMovement);
      expect(
        cashWithdrawal.financialActionSemantics,
        FinancialActionSemantics.cashWithdrawal,
      );

      expect(adjustment, isNotNull);
      expect(adjustment!.spendingRole, SpendingRole.nonBudgetFinancialAction);
      expect(adjustment.financialImpact, FinancialImpact.dataAdjustment);
      expect(
        adjustment.financialActionSemantics,
        FinancialActionSemantics.adjustment,
      );
    });
  });
}

const _specialFinancialActions = {
  CategoryStableKey.expenseFinanceSavings,
  CategoryStableKey.expenseFinanceInvestments,
  CategoryStableKey.expenseFinanceTfsaContribution,
  CategoryStableKey.expenseFinanceRrspContribution,
  CategoryStableKey.expenseFinanceRespContribution,
  CategoryStableKey.expenseFinanceEmergencyFund,
  CategoryStableKey.expenseFinanceDebtRepayment,
  CategoryStableKey.expenseFinanceCreditCardPayment,
  CategoryStableKey.expenseFinanceLoanPayment,
  CategoryStableKey.expenseOtherCashWithdrawal,
  CategoryStableKey.expenseOtherAdjustment,
};

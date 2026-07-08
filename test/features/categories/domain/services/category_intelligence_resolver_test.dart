import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/enums/financial_impact.dart';
import 'package:ophir/features/categories/domain/services/category_intelligence_resolver.dart';

void main() {
  const resolver = CategoryIntelligenceResolver();

  group('CategoryIntelligenceResolver', () {
    test('valid stableKey resolves profile', () {
      final category = _category(
        nameKey: 'categoryUnknownLegacy',
        stableKey: CategoryStableKey.expenseHousingRent.toJson(),
      );

      final profile = resolver.profileFor(category);

      expect(profile, isNotNull);
      expect(profile!.stableKey, CategoryStableKey.expenseHousingRent);
    });

    test('stableKey is preferred over nameKey', () {
      final category = _category(
        nameKey: 'categoryGroceries',
        stableKey: CategoryStableKey.expenseHousingRent.toJson(),
      );

      final profile = resolver.profileFor(category);

      expect(profile, isNotNull);
      expect(profile!.stableKey, CategoryStableKey.expenseHousingRent);
    });

    test('invalid stableKey returns null', () {
      final category = _category(
        nameKey: 'categoryGroceries',
        stableKey: 'expense.unknown.invalid',
      );

      expect(resolver.profileFor(category), isNull);
    });

    test('type mismatch returns null', () {
      final category = _category(
        type: CategoryType.expense,
        nameKey: 'categoryGroceries',
        stableKey: CategoryStableKey.incomeEmploymentSalary.toJson(),
      );

      expect(resolver.profileFor(category), isNull);
    });

    test('approved legacy category without stableKey resolves profile', () {
      final category = _category(nameKey: 'categoryGroceries');

      final profile = resolver.profileFor(category);

      expect(profile, isNotNull);
      expect(profile!.stableKey, CategoryStableKey.expenseFoodGroceries);
    });

    test('broad legacy category without stableKey returns null', () {
      final category = _category(nameKey: 'categoryUtilities');

      expect(resolver.profileFor(category), isNull);
    });

    test('profile type matches category type', () {
      final expense = _category(
        nameKey: 'categoryRent',
        stableKey: CategoryStableKey.expenseHousingRent.toJson(),
      );
      final income = _category(
        type: CategoryType.income,
        nameKey: 'categorySalary',
        stableKey: CategoryStableKey.incomeEmploymentSalary.toJson(),
      );

      final expenseProfile = resolver.profileFor(expense);
      final incomeProfile = resolver.profileFor(income);

      expect(expenseProfile, isNotNull);
      expect(expenseProfile!.type, CategoryType.expense);
      expect(incomeProfile, isNotNull);
      expect(incomeProfile!.type, CategoryType.income);
    });

    test('special financial category resolves non-ordinary profile', () {
      final category = _category(
        nameKey: 'categorySavings',
        stableKey: CategoryStableKey.expenseFinanceSavings.toJson(),
      );

      final profile = resolver.profileFor(category);

      expect(profile, isNotNull);
      expect(profile!.isOrdinarySpending, isFalse);
      expect(profile.financialImpact, FinancialImpact.assetBuilding);
    });

    test('transfer-like non-taxonomy category remains unresolved', () {
      final category = _category(
        nameKey: 'categoryGroceries',
        stableKey: 'transfer.internal.account_transfer',
      );

      expect(resolver.profileFor(category), isNull);
    });
  });
}

Category _category({
  CategoryType type = CategoryType.expense,
  required String nameKey,
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

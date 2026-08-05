import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/aggregation/app_category_group_summary.dart';
import 'package:ophir/core/categories/app_categories.dart';

void main() {
  group('AppCategoryGroupSummaryBuilder', () {
    test('sums planned entries by group', () {
      final summaries = AppCategoryGroupSummaryBuilder.build(
        categoryScope: [
          AppCategories.expenseFoodGroceries,
          AppCategories.expenseFoodRestaurant,
          AppCategories.expenseHousingRent,
        ],
        plannedEntries: const [
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 25,
          ),
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodRestaurant,
            amount: 10,
          ),
        ],
        actualEntries: const <AppCategoryAmountEntry>[],
      );

      expect(_summary(summaries, AppCategoryGroup.food).plannedAmount, 35);
      expect(_summary(summaries, AppCategoryGroup.housing).plannedAmount, 0);
    });

    test('sums actual entries by group', () {
      final summaries = AppCategoryGroupSummaryBuilder.build(
        categoryScope: [
          AppCategories.expenseFoodGroceries,
          AppCategories.expenseFoodRestaurant,
        ],
        plannedEntries: const <AppCategoryAmountEntry>[],
        actualEntries: const [
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 25,
          ),
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodRestaurant,
            amount: 10,
          ),
        ],
      );

      expect(_summary(summaries, AppCategoryGroup.food).actualAmount, 35);
    });

    test('does not mix planned and actual amounts', () {
      final summaries = AppCategoryGroupSummaryBuilder.build(
        categoryScope: [AppCategories.expenseFoodGroceries],
        plannedEntries: const [
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 40,
          ),
        ],
        actualEntries: const [
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 15,
          ),
        ],
      );
      final summary = _summary(summaries, AppCategoryGroup.food);

      expect(summary.plannedAmount, 40);
      expect(summary.actualAmount, 15);
    });

    test('counts multiple entries of one category once', () {
      final summaries = AppCategoryGroupSummaryBuilder.build(
        categoryScope: [AppCategories.expenseFoodGroceries],
        plannedEntries: const [
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 40,
          ),
        ],
        actualEntries: const [
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 15,
          ),
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 20,
          ),
        ],
      );

      expect(_summary(summaries, AppCategoryGroup.food).activeCategoryCount, 1);
    });

    test('counts different categories in one group separately', () {
      final summaries = AppCategoryGroupSummaryBuilder.build(
        categoryScope: [
          AppCategories.expenseFoodGroceries,
          AppCategories.expenseFoodRestaurant,
        ],
        plannedEntries: const [
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 40,
          ),
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodRestaurant,
            amount: 15,
          ),
        ],
        actualEntries: const <AppCategoryAmountEntry>[],
      );

      expect(_summary(summaries, AppCategoryGroup.food).activeCategoryCount, 2);
    });

    test('preserves canonical group order from category scope', () {
      final summaries = AppCategoryGroupSummaryBuilder.build(
        categoryScope: [
          AppCategories.expenseHousingRent,
          AppCategories.expenseFoodGroceries,
          AppCategories.expenseTransportationFuel,
        ],
        plannedEntries: const <AppCategoryAmountEntry>[],
        actualEntries: const <AppCategoryAmountEntry>[],
      );

      expect(summaries.map((summary) => summary.group), [
        AppCategoryGroup.housing,
        AppCategoryGroup.food,
        AppCategoryGroup.transportation,
      ]);
    });

    test('includes empty groups with zero amounts', () {
      final summaries = AppCategoryGroupSummaryBuilder.build(
        categoryScope: [
          AppCategories.expenseHousingRent,
          AppCategories.expenseFoodGroceries,
        ],
        plannedEntries: const [
          AppCategoryAmountEntry(
            category: AppCategories.expenseFoodGroceries,
            amount: 15,
          ),
        ],
        actualEntries: const <AppCategoryAmountEntry>[],
      );
      final housing = _summary(summaries, AppCategoryGroup.housing);

      expect(housing.plannedAmount, 0);
      expect(housing.actualAmount, 0);
      expect(housing.activeCategoryCount, 0);
    });

    test('returns immutable collections', () {
      final summaries = AppCategoryGroupSummaryBuilder.build(
        categoryScope: [AppCategories.expenseFoodGroceries],
        plannedEntries: const <AppCategoryAmountEntry>[],
        actualEntries: const <AppCategoryAmountEntry>[],
      );

      expect(
        () => summaries.add(
          const AppCategoryGroupFinancialSummary(
            group: AppCategoryGroup.food,
            plannedAmount: 0,
            actualAmount: 0,
            activeCategoryCount: 0,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('calculates difference and over-budget state', () {
      const summary = AppCategoryGroupFinancialSummary(
        group: AppCategoryGroup.food,
        plannedAmount: 40,
        actualAmount: 55,
        activeCategoryCount: 1,
      );

      expect(summary.difference, 15);
      expect(summary.isOverBudget, isTrue);
    });
  });
}

AppCategoryGroupFinancialSummary _summary(
  List<AppCategoryGroupFinancialSummary> summaries,
  AppCategoryGroup group,
) {
  return summaries.singleWhere((summary) => summary.group == group);
}

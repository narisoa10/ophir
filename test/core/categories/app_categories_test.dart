import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';

void main() {
  group('AppCategories', () {
    test('contains the expected number of categories', () {
      expect(AppCategoryId.values, hasLength(148));
      expect(AppCategories.all, hasLength(148));
      expect(AppCategories.expenseCategories, hasLength(122));
      expect(AppCategories.incomeCategories, hasLength(26));
    });

    test('expenseCategories contains only expense categories', () {
      expect(
        AppCategories.expenseCategories,
        everyElement(
          isA<AppCategory>().having(
            (category) => category.type,
            'type',
            AppCategoryType.expense,
          ),
        ),
      );
    });

    test('incomeCategories contains only income role categories', () {
      expect(
        AppCategories.incomeCategories,
        everyElement(
          isA<AppCategory>().having(
            (category) => category.role,
            'role',
            AppCategoryRole.income,
          ),
        ),
      );
    });

    test('uses unique ids', () {
      expect(
        AppCategories.all.map((category) => category.id).toSet(),
        hasLength(AppCategories.all.length),
      );
    });

    test('matches expected role counts', () {
      final counts = {
        for (final role in AppCategoryRole.values)
          role: AppCategories.all
              .where((category) => category.role == role)
              .length,
      };

      expect(counts[AppCategoryRole.mandatory], 53);
      expect(counts[AppCategoryRole.flexible], 28);
      expect(counts[AppCategoryRole.want], 16);
      expect(counts[AppCategoryRole.debtPayment], 4);
      expect(counts[AppCategoryRole.saving], 2);
      expect(counts[AppCategoryRole.investment], 16);
      expect(counts[AppCategoryRole.transfer], 1);
      expect(counts[AppCategoryRole.income], 26);
      expect(counts[AppCategoryRole.other], 2);
    });

    test('builds mandatory housing and transportation from AppCategories', () {
      final housing = AppCategories.mandatoryExpenseCategories(
        AppCategoryGroup.housing,
      );
      final transportation = AppCategories.mandatoryExpenseCategories(
        AppCategoryGroup.transportation,
      );

      expect(
        housing.map((category) => category.id),
        containsAll([
          AppCategoryId.expenseHousingRent,
          AppCategoryId.expenseHousingMortgage,
          AppCategoryId.expenseHousingPropertyTax,
          AppCategoryId.expenseHousingCondoFees,
          AppCategoryId.expenseHousingElectricity,
          AppCategoryId.expenseHousingNaturalGas,
          AppCategoryId.expenseHousingWater,
          AppCategoryId.expenseHousingSewer,
          AppCategoryId.expenseHousingGarbageCollection,
          AppCategoryId.expenseHousingInternet,
          AppCategoryId.expenseHousingMobilePhone,
          AppCategoryId.expenseHousingHomePhone,
          AppCategoryId.expenseHousingHomeInsurance,
        ]),
      );
      expect(transportation.map((category) => category.id), [
        AppCategoryId.expenseTransportationFuel,
        AppCategoryId.expenseTransportationEvCharging,
        AppCategoryId.expenseTransportationPublicTransit,
        AppCategoryId.expenseTransportationAutoInsurance,
        AppCategoryId.expenseTransportationVehicleRegistration,
      ]);
    });

    test('groupByGroup preserves first group appearance order', () {
      final grouped = AppCategories.groupByGroup([
        AppCategories.expenseFoodGroceries,
        AppCategories.expenseHousingRent,
        AppCategories.expenseFoodRestaurant,
      ]);

      expect(grouped.keys.toList(growable: false), [
        AppCategoryGroup.food,
        AppCategoryGroup.housing,
      ]);
    });

    test('groupByGroup preserves category order inside each group', () {
      final grouped = AppCategories.groupByGroup([
        AppCategories.expenseFoodGroceries,
        AppCategories.expenseHousingRent,
        AppCategories.expenseFoodRestaurant,
        AppCategories.expenseFoodCafeCoffee,
      ]);

      expect(grouped[AppCategoryGroup.food], [
        AppCategories.expenseFoodGroceries,
        AppCategories.expenseFoodRestaurant,
        AppCategories.expenseFoodCafeCoffee,
      ]);
    });

    test('groupByGroup cannot be modified from outside', () {
      final grouped = AppCategories.groupByGroup([
        AppCategories.expenseFoodGroceries,
        AppCategories.expenseHousingRent,
      ]);

      expect(
        () =>
            grouped[AppCategoryGroup.governmentExpense] = const <AppCategory>[],
        throwsUnsupportedError,
      );
      expect(
        () => grouped[AppCategoryGroup.food]!.add(
          AppCategories.expenseFoodRestaurant,
        ),
        throwsUnsupportedError,
      );
    });
  });
}

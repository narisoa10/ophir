import '../enums/category_analytics_group.dart';
import '../enums/category_ui_group.dart';

final class CategoryGroupResolver {
  const CategoryGroupResolver();

  CategoryUiGroup resolveUiGroup({
    required String nameKey,
    required String legacyGroupKey,
  }) {
    return switch (nameKey) {
      'categoryRent' ||
      'categoryMortgage' ||
      'categoryUtilities' ||
      'categoryInsurance' => CategoryUiGroup.housing,
      'categoryFuel' ||
      'categoryPublicTransit' ||
      'categoryCar' => CategoryUiGroup.transport,
      'categoryGroceries' ||
      'categoryOtherExpense' => CategoryUiGroup.dailyLife,
      'categoryRestaurants' ||
      'categoryCoffee' ||
      'categoryShopping' => CategoryUiGroup.outingsShopping,
      'categoryEntertainment' ||
      'categorySubscriptions' ||
      'categoryTravel' => CategoryUiGroup.leisure,
      'categoryDebtPayment' ||
      'categoryBankFees' ||
      'categorySavings' ||
      'categoryInvestments' => CategoryUiGroup.financeSavings,
      'categoryHealth' || 'categoryPharmacy' => CategoryUiGroup.health,
      'categoryEducation' => CategoryUiGroup.development,
      'categorySalary' ||
      'categoryBusiness' ||
      'categoryBenefits' ||
      'categoryDividends' ||
      'categoryOtherIncome' => CategoryUiGroup.income,
      _ => CategoryUiGroup.fromLegacyGroupKey(legacyGroupKey),
    };
  }

  CategoryAnalyticsGroup resolveAnalyticsGroup({
    required String nameKey,
    required String legacyGroupKey,
  }) {
    return switch (nameKey) {
      'categoryRent' ||
      'categoryMortgage' ||
      'categoryUtilities' ||
      'categoryInsurance' ||
      'categoryGroceries' ||
      'categoryFuel' ||
      'categoryPublicTransit' ||
      'categoryCar' => CategoryAnalyticsGroup.essentialExpenses,
      'categoryRestaurants' ||
      'categoryCoffee' ||
      'categoryShopping' ||
      'categoryOtherExpense' => CategoryAnalyticsGroup.flexibleExpenses,
      'categoryEntertainment' ||
      'categorySubscriptions' ||
      'categoryTravel' => CategoryAnalyticsGroup.lifestyleEntertainment,
      'categoryDebtPayment' ||
      'categoryBankFees' ||
      'categorySavings' ||
      'categoryInvestments' => CategoryAnalyticsGroup.financeSavings,
      'categoryHealth' ||
      'categoryPharmacy' ||
      'categoryEducation' => CategoryAnalyticsGroup.healthDevelopment,
      'categorySalary' ||
      'categoryBusiness' ||
      'categoryBenefits' ||
      'categoryDividends' ||
      'categoryOtherIncome' => CategoryAnalyticsGroup.income,
      _ => CategoryAnalyticsGroup.fromLegacyGroupKey(legacyGroupKey),
    };
  }
}

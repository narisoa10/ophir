import '../../../../core/icons/app_category_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/category_taxonomy.dart';
import '../../domain/enums/category_type.dart';
import '../models/category_presentation.dart';
import 'category_definition_adapter.dart';
import 'category_group_adapter.dart';
import 'expense_category_group_adapter.dart';
import 'income_category_group_adapter.dart';

final class CategoryAdapter {
  const CategoryAdapter();

  CategoryPresentation toPresentation(
    Category category,
    AppLocalizations l10n,
  ) {
    final taxonomyPresentation = _taxonomyPresentation(category, l10n);
    if (taxonomyPresentation != null) {
      return taxonomyPresentation;
    }

    const groupAdapter = CategoryGroupAdapter();

    return CategoryPresentation(
      name: _localizedName(category.nameKey, l10n),
      uiGroupName: groupAdapter.label(category.uiGroup, l10n),
      example: _localizedExample(category.exampleKey, l10n),
      icon: AppCategoryIcons.fromKey(category.iconKey),
      color: AppCategoryColors.fromKey(category.colorKey),
      backgroundColor: AppCategoryColors.backgroundFromKey(category.colorKey),
    );
  }

  CategoryPresentation? _taxonomyPresentation(
    Category category,
    AppLocalizations l10n,
  ) {
    final stableKey = category.stableKey;
    if (stableKey == null) {
      return null;
    }

    final definition = CategoryTaxonomy.definitionForStableKey(stableKey);
    if (definition == null) {
      return null;
    }

    const definitionAdapter = CategoryDefinitionAdapter();
    final definitionPresentation = definitionAdapter.toPresentation(
      definition,
      l10n,
    );
    final groupName = switch (definition.type) {
      CategoryType.expense => const ExpenseCategoryGroupAdapter().label(
        definition.expenseGroup!,
        l10n,
      ),
      CategoryType.income => const IncomeCategoryGroupAdapter().label(
        definition.incomeGroup!,
        l10n,
      ),
    };

    return CategoryPresentation(
      name: definitionPresentation.name,
      uiGroupName: groupName,
      example: _localizedExample(category.exampleKey, l10n),
      icon: definitionPresentation.icon,
      color: definitionPresentation.color,
      backgroundColor: definitionPresentation.backgroundColor,
    );
  }

  String _localizedName(String key, AppLocalizations l10n) {
    return switch (key) {
      'categoryRent' => l10n.categoryRent,
      'categoryMortgage' => l10n.categoryMortgage,
      'categoryUtilities' => l10n.categoryUtilities,
      'categoryInsurance' => l10n.categoryInsurance,
      'categoryGroceries' => l10n.categoryGroceries,
      'categoryRestaurants' => l10n.categoryRestaurants,
      'categoryCoffee' => l10n.categoryCoffee,
      'categoryFuel' => l10n.categoryFuel,
      'categoryPublicTransit' => l10n.categoryPublicTransit,
      'categoryCar' => l10n.categoryCar,
      'categoryHealth' => l10n.categoryHealth,
      'categoryPharmacy' => l10n.categoryPharmacy,
      'categoryShopping' => l10n.categoryShopping,
      'categoryEntertainment' => l10n.categoryEntertainment,
      'categorySubscriptions' => l10n.categorySubscriptions,
      'categoryTravel' => l10n.categoryTravel,
      'categoryEducation' => l10n.categoryEducation,
      'categoryDebtPayment' => l10n.categoryDebtPayment,
      'categoryBankFees' => l10n.categoryBankFees,
      'categorySavings' => l10n.categorySavings,
      'categoryInvestments' => l10n.categoryInvestments,
      'categoryOtherExpense' => l10n.categoryOtherExpense,
      'categorySalary' => l10n.categorySalary,
      'categoryBusiness' => l10n.categoryBusiness,
      'categoryBenefits' => l10n.categoryBenefits,
      'categoryDividends' => l10n.categoryDividends,
      'categoryOtherIncome' => l10n.categoryOtherIncome,
      _ => key,
    };
  }

  String _localizedExample(String key, AppLocalizations l10n) {
    return switch (key) {
      'categoryExampleRent' => l10n.categoryExampleRent,
      'categoryExampleMortgage' => l10n.categoryExampleMortgage,
      'categoryExampleUtilities' => l10n.categoryExampleUtilities,
      'categoryExampleInsurance' => l10n.categoryExampleInsurance,
      'categoryExampleGroceries' => l10n.categoryExampleGroceries,
      'categoryExampleRestaurants' => l10n.categoryExampleRestaurants,
      'categoryExampleCoffee' => l10n.categoryExampleCoffee,
      'categoryExampleFuel' => l10n.categoryExampleFuel,
      'categoryExamplePublicTransit' => l10n.categoryExamplePublicTransit,
      'categoryExampleCar' => l10n.categoryExampleCar,
      'categoryExampleHealth' => l10n.categoryExampleHealth,
      'categoryExamplePharmacy' => l10n.categoryExamplePharmacy,
      'categoryExampleShopping' => l10n.categoryExampleShopping,
      'categoryExampleEntertainment' => l10n.categoryExampleEntertainment,
      'categoryExampleSubscriptions' => l10n.categoryExampleSubscriptions,
      'categoryExampleTravel' => l10n.categoryExampleTravel,
      'categoryExampleEducation' => l10n.categoryExampleEducation,
      'categoryExampleDebtPayment' => l10n.categoryExampleDebtPayment,
      'categoryExampleBankFees' => l10n.categoryExampleBankFees,
      'categoryExampleSavings' => l10n.categoryExampleSavings,
      'categoryExampleInvestments' => l10n.categoryExampleInvestments,
      'categoryExampleOtherExpense' => l10n.categoryExampleOtherExpense,
      'categoryExampleSalary' => l10n.categoryExampleSalary,
      'categoryExampleBusiness' => l10n.categoryExampleBusiness,
      'categoryExampleBenefits' => l10n.categoryExampleBenefits,
      'categoryExampleDividends' => l10n.categoryExampleDividends,
      'categoryExampleOtherIncome' => l10n.categoryExampleOtherIncome,
      'categoryExampleDefault' => l10n.categoryExampleDefault,
      _ => l10n.categoryExampleDefault,
    };
  }
}

import '../enums/category_stable_key.dart';
import 'category.dart';
import 'category_definition.dart';
import 'category_taxonomy.dart';

final class LegacyCategoryBridge {
  const LegacyCategoryBridge();

  CategoryStableKey? stableKeyFor(Category category) {
    final definition = definitionFor(category);
    return definition?.key;
  }

  CategoryDefinition? definitionFor(Category category) {
    final stableKey = category.stableKey;

    if (stableKey == null) {
      return _legacyDefinitionFor(category);
    }

    final definition = CategoryTaxonomy.definitionForStableKey(stableKey);

    if (definition?.type != category.type) {
      return null;
    }

    return definition;
  }

  bool hasDefinition(Category category) {
    return definitionFor(category) != null;
  }

  CategoryDefinition? _legacyDefinitionFor(Category category) {
    final stableKey = _approvedLegacyNameKeyMap[category.nameKey];

    if (stableKey == null) {
      return null;
    }

    final definition = CategoryTaxonomy.definitionFor(stableKey);

    if (definition?.type != category.type) {
      return null;
    }

    return definition;
  }
}

const Map<String, CategoryStableKey> _approvedLegacyNameKeyMap = {
  'categoryRent': CategoryStableKey.expenseHousingRent,
  'categoryMortgage': CategoryStableKey.expenseHousingMortgage,
  'categoryGroceries': CategoryStableKey.expenseFoodGroceries,
  'categoryRestaurants': CategoryStableKey.expenseFoodRestaurant,
  'categoryCoffee': CategoryStableKey.expenseFoodCafeCoffee,
  'categoryFuel': CategoryStableKey.expenseTransportationFuel,
  'categoryPublicTransit': CategoryStableKey.expenseTransportationPublicTransit,
  'categoryPharmacy': CategoryStableKey.expenseHealthPharmacy,
  'categorySubscriptions':
      CategoryStableKey.expenseEntertainmentLifestyleStreamingSubscriptions,
  'categoryTravel': CategoryStableKey.expenseEntertainmentLifestyleTravel,
  'categoryDebtPayment': CategoryStableKey.expenseFinanceDebtRepayment,
  'categoryBankFees': CategoryStableKey.expenseFinanceBankFees,
  'categorySavings': CategoryStableKey.expenseFinanceSavings,
  'categoryInvestments': CategoryStableKey.expenseFinanceInvestments,
  'categoryOtherExpense': CategoryStableKey.expenseOtherUncategorized,
  'categorySalary': CategoryStableKey.incomeEmploymentSalary,
  'categoryBenefits': CategoryStableKey.incomeGovernmentGovernmentBenefits,
  'categoryDividends': CategoryStableKey.incomeInvestmentsDividendIncome,
  'categoryOtherIncome': CategoryStableKey.incomeOtherIncomeOtherIncome,
};

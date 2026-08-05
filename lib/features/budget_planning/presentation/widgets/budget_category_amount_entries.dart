import '../../../../core/categories/aggregation/app_category_group_summary.dart';
import '../../../../core/categories/app_categories.dart';
import '../../domain/entities/budget_obligation.dart';

List<AppCategoryAmountEntry> budgetPlannedCategoryAmountEntries(
  Iterable<BudgetObligation> obligations,
) {
  return [
    for (final obligation in obligations)
      if (AppCategories.byIdName(obligation.categoryId) case final category?)
        AppCategoryAmountEntry(category: category, amount: obligation.amount),
  ];
}

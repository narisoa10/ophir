import '../../../../core/categories/aggregation/app_category_group_summary.dart';
import '../../../../core/categories/app_categories.dart';
import '../../domain/entities/operation.dart';

List<AppCategoryAmountEntry> operationActualCategoryAmountEntries(
  Iterable<Operation> operations,
) {
  return [
    for (final operation in operations)
      if (AppCategories.byIdName(operation.categoryId) case final category?)
        AppCategoryAmountEntry(category: category, amount: operation.amount),
  ];
}

List<AppCategoryGroupFinancialSummary> operationActualCategorySummaries(
  Iterable<Operation> operations,
) {
  return AppCategoryGroupSummaryBuilder.build(
    categoryScope: [
      ...AppCategories.expenseCategories,
      ...AppCategories.incomeCategories,
    ],
    plannedEntries: const <AppCategoryAmountEntry>[],
    actualEntries: operationActualCategoryAmountEntries(operations),
  );
}

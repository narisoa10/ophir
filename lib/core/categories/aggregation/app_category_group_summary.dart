import '../app_categories.dart';

final class AppCategoryAmountEntry {
  const AppCategoryAmountEntry({required this.category, required this.amount});

  final AppCategory category;
  final double amount;
}

final class AppCategoryGroupFinancialSummary {
  const AppCategoryGroupFinancialSummary({
    required this.group,
    required this.plannedAmount,
    required this.actualAmount,
    required this.activeCategoryCount,
  });

  final AppCategoryGroup group;
  final double plannedAmount;
  final double actualAmount;
  final int activeCategoryCount;

  double get difference => actualAmount - plannedAmount;

  bool get isOverBudget => actualAmount > plannedAmount;
}

final class AppCategoryGroupSummaryBuilder {
  const AppCategoryGroupSummaryBuilder._();

  static List<AppCategoryGroupFinancialSummary> build({
    required Iterable<AppCategory> categoryScope,
    required Iterable<AppCategoryAmountEntry> plannedEntries,
    required Iterable<AppCategoryAmountEntry> actualEntries,
  }) {
    final scopedCategories = categoryScope.toList(growable: false);
    final groupedCategories = AppCategories.groupByGroup(scopedCategories);
    final scopeIds = {for (final category in scopedCategories) category.id};
    final plannedAmounts = <AppCategoryGroup, double>{};
    final actualAmounts = <AppCategoryGroup, double>{};
    final activeCategoryIds = <AppCategoryGroup, Set<AppCategoryId>>{};

    void addEntry(
      AppCategoryAmountEntry entry,
      Map<AppCategoryGroup, double> amounts,
    ) {
      final category = entry.category;

      if (!scopeIds.contains(category.id)) {
        return;
      }

      amounts[category.group] = (amounts[category.group] ?? 0) + entry.amount;
      activeCategoryIds
          .putIfAbsent(category.group, () => <AppCategoryId>{})
          .add(category.id);
    }

    for (final entry in plannedEntries) {
      addEntry(entry, plannedAmounts);
    }

    for (final entry in actualEntries) {
      addEntry(entry, actualAmounts);
    }

    return List<AppCategoryGroupFinancialSummary>.unmodifiable([
      for (final group in groupedCategories.keys)
        AppCategoryGroupFinancialSummary(
          group: group,
          plannedAmount: plannedAmounts[group] ?? 0,
          actualAmount: actualAmounts[group] ?? 0,
          activeCategoryCount: activeCategoryIds[group]?.length ?? 0,
        ),
    ]);
  }
}

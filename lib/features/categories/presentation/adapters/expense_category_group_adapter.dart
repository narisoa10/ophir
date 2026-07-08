import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/enums/expense_category_group.dart';
import '../models/category_group_presentation.dart';

final class ExpenseCategoryGroupAdapter {
  const ExpenseCategoryGroupAdapter();

  CategoryGroupPresentation toPresentation(
    ExpenseCategoryGroup group,
    AppLocalizations l10n,
  ) {
    return CategoryGroupPresentation(
      key: group.l10nKey,
      name: label(group, l10n),
      sortOrder: ExpenseCategoryGroup.values.indexOf(group),
    );
  }

  String label(ExpenseCategoryGroup group, AppLocalizations l10n) {
    return switch (group) {
      ExpenseCategoryGroup.housing => l10n.categoryGroupExpenseHousing,
      ExpenseCategoryGroup.food => l10n.categoryGroupExpenseFood,
      ExpenseCategoryGroup.transportation =>
        l10n.categoryGroupExpenseTransportation,
      ExpenseCategoryGroup.health => l10n.categoryGroupExpenseHealth,
      ExpenseCategoryGroup.family => l10n.categoryGroupExpenseFamily,
      ExpenseCategoryGroup.personalCare =>
        l10n.categoryGroupExpensePersonalCare,
      ExpenseCategoryGroup.entertainmentLifestyle =>
        l10n.categoryGroupExpenseEntertainmentLifestyle,
      ExpenseCategoryGroup.education => l10n.categoryGroupExpenseEducation,
      ExpenseCategoryGroup.finance => l10n.categoryGroupExpenseFinance,
      ExpenseCategoryGroup.government => l10n.categoryGroupExpenseGovernment,
      ExpenseCategoryGroup.pets => l10n.categoryGroupExpensePets,
      ExpenseCategoryGroup.giving => l10n.categoryGroupExpenseGiving,
      ExpenseCategoryGroup.work => l10n.categoryGroupExpenseWork,
      ExpenseCategoryGroup.other => l10n.categoryGroupExpenseOther,
    };
  }
}

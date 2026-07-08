import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/enums/income_category_group.dart';
import '../models/category_group_presentation.dart';

final class IncomeCategoryGroupAdapter {
  const IncomeCategoryGroupAdapter();

  CategoryGroupPresentation toPresentation(
    IncomeCategoryGroup group,
    AppLocalizations l10n,
  ) {
    return CategoryGroupPresentation(
      key: group.l10nKey,
      name: label(group, l10n),
      sortOrder: IncomeCategoryGroup.values.indexOf(group),
    );
  }

  String label(IncomeCategoryGroup group, AppLocalizations l10n) {
    return switch (group) {
      IncomeCategoryGroup.employment => l10n.categoryGroupIncomeEmployment,
      IncomeCategoryGroup.business => l10n.categoryGroupIncomeBusiness,
      IncomeCategoryGroup.investments => l10n.categoryGroupIncomeInvestments,
      IncomeCategoryGroup.government => l10n.categoryGroupIncomeGovernment,
      IncomeCategoryGroup.gifts => l10n.categoryGroupIncomeGifts,
      IncomeCategoryGroup.otherIncome => l10n.categoryGroupIncomeOtherIncome,
    };
  }
}

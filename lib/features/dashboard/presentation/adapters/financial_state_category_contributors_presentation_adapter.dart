import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_financial_state_l10n.dart';
import '../../../assistant/domain/entities/financial_state_category_contributors_snapshot.dart';
import '../../../assistant/domain/entities/financial_state_type.dart';
import '../../../categories/domain/entities/category_taxonomy.dart';
import '../../../categories/presentation/adapters/category_definition_adapter.dart';
import '../models/dashboard_financial_state_category_contributor_presentation.dart';
import '../models/dashboard_financial_state_category_contributors_presentation.dart';

final class FinancialStateCategoryContributorsPresentationAdapter {
  const FinancialStateCategoryContributorsPresentationAdapter();

  DashboardFinancialStateCategoryContributorsPresentation toPresentation({
    required FinancialStateCategoryContributorsSnapshot snapshot,
    required AppLocalizations l10n,
    required String Function(double amount, String currencyCode) formatMoney,
  }) {
    return DashboardFinancialStateCategoryContributorsPresentation(
      title: _title(snapshot.stateType, l10n),
      contributors: _contributors(snapshot, l10n, formatMoney),
    );
  }

  String _title(FinancialStateType stateType, AppLocalizations l10n) {
    return switch (stateType) {
      FinancialStateType.deficit => l10n.dashboardContributorDeficitTitle,
      FinancialStateType.fragileBalance =>
        l10n.dashboardContributorFragileTitle,
      FinancialStateType.stable => l10n.dashboardContributorStableTitle,
      FinancialStateType.growth => l10n.dashboardContributorGrowthTitle,
      FinancialStateType.strongPosition =>
        l10n.dashboardContributorStrongPositionTitle,
    };
  }

  List<DashboardFinancialStateCategoryContributorPresentation> _contributors(
    FinancialStateCategoryContributorsSnapshot snapshot,
    AppLocalizations l10n,
    String Function(double amount, String currencyCode) formatMoney,
  ) {
    final adapter = const CategoryDefinitionAdapter();
    final contributors =
        <DashboardFinancialStateCategoryContributorPresentation>[];

    for (final contributor in snapshot.contributors) {
      final definition = CategoryTaxonomy.definitionFor(contributor.stableKey)!;
      final category = adapter.toPresentation(definition, l10n);
      contributors.add(
        DashboardFinancialStateCategoryContributorPresentation(
          categoryId: contributor.categoryId,
          name: category.name,
          amount: _amount(
            contributor.amount,
            snapshot.currencyCode,
            formatMoney,
          ),
          percentOfIncome: _percent(contributor.percentOfIncome),
          roleLabel: l10n.dashboardContributorDistributionRole(
            contributor.distributionRole,
          ),
          icon: category.icon,
          color: category.color,
          backgroundColor: category.backgroundColor,
        ),
      );
    }

    return contributors;
  }

  String _amount(
    double amount,
    String? currencyCode,
    String Function(double amount, String currencyCode) formatMoney,
  ) {
    if (currencyCode == null) {
      return amount.toStringAsFixed(2);
    }
    return formatMoney(amount, currencyCode);
  }

  String? _percent(double? value) {
    if (value == null) {
      return null;
    }
    return '${value.toStringAsFixed(1)}%';
  }
}

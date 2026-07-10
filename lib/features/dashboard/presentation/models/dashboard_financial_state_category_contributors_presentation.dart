import 'dashboard_financial_state_category_contributor_presentation.dart';

final class DashboardFinancialStateCategoryContributorsPresentation {
  DashboardFinancialStateCategoryContributorsPresentation({
    required this.title,
    required List<DashboardFinancialStateCategoryContributorPresentation>
    contributors,
  }) : contributors = List.unmodifiable(contributors);

  final String title;
  final List<DashboardFinancialStateCategoryContributorPresentation>
  contributors;
}

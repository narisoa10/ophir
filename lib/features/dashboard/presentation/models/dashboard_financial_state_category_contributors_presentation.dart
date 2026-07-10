import 'dashboard_financial_state_category_contributor_presentation.dart';

final class DashboardFinancialStateCategoryContributorsPresentation {
  DashboardFinancialStateCategoryContributorsPresentation({
    required this.title,
    required this.requiredAmountLabel,
    required this.requiredAmount,
    required this.coveredAmountLabel,
    required this.coveredAmount,
    required this.isCoverageComplete,
    required List<DashboardFinancialStateCategoryContributorPresentation>
    contributors,
  }) : contributors = List.unmodifiable(contributors);

  final String title;
  final String requiredAmountLabel;
  final String requiredAmount;
  final String coveredAmountLabel;
  final String coveredAmount;
  final bool isCoverageComplete;
  final List<DashboardFinancialStateCategoryContributorPresentation>
  contributors;
}

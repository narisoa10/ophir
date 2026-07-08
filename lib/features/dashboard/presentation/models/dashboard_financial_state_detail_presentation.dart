import 'dashboard_period_distribution_item_presentation.dart';

final class DashboardFinancialStateDetailPresentation {
  const DashboardFinancialStateDetailPresentation({
    required this.title,
    required this.currentStateTitle,
    required this.currentStateDescription,
    required this.whyTitle,
    required this.whyDescription,
    required this.problemsTitle,
    required this.problems,
    required this.influenceTitle,
    required this.buckets,
    required this.recommendationTitle,
    required this.recommendationDescription,
    required this.evidenceTitle,
    required this.evidence,
  });

  final String title;
  final String currentStateTitle;
  final String currentStateDescription;
  final String whyTitle;
  final String whyDescription;
  final String problemsTitle;
  final List<String> problems;
  final String influenceTitle;
  final List<DashboardPeriodDistributionItemPresentation> buckets;
  final String recommendationTitle;
  final String recommendationDescription;
  final String evidenceTitle;
  final List<String> evidence;
}

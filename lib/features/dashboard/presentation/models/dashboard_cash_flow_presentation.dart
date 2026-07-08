import 'dashboard_metric_presentation.dart';

final class DashboardCashFlowPresentation {
  const DashboardCashFlowPresentation({
    required this.income,
    required this.expenses,
    required this.net,
    required this.summary,
    required this.groups,
  });

  final String income;
  final String expenses;
  final String net;
  final String summary;
  final List<DashboardMetricPresentation> groups;
}

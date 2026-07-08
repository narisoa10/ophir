import '../../../categories/domain/enums/category_analytics_group.dart';

final class DashboardExpenseGroupSummary {
  const DashboardExpenseGroupSummary({
    required this.analyticsGroup,
    required this.amount,
  });

  final CategoryAnalyticsGroup analyticsGroup;
  final double amount;
}

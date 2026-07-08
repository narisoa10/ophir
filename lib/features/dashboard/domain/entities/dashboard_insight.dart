import '../../../categories/domain/enums/category_analytics_group.dart';
import 'dashboard_insight_type.dart';

final class DashboardInsight {
  const DashboardInsight({
    required this.type,
    this.amount,
    this.count,
    this.analyticsGroup,
  });

  final DashboardInsightType type;
  final double? amount;
  final int? count;
  final CategoryAnalyticsGroup? analyticsGroup;
}

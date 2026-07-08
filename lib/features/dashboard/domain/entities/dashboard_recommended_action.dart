import '../../../categories/domain/enums/category_analytics_group.dart';
import 'dashboard_action_type.dart';

final class DashboardRecommendedAction {
  const DashboardRecommendedAction({
    required this.type,
    this.amount,
    this.count,
    this.analyticsGroup,
  });

  final DashboardActionType type;
  final double? amount;
  final int? count;
  final CategoryAnalyticsGroup? analyticsGroup;
}

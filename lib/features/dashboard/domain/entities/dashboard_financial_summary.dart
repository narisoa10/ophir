import 'dashboard_cash_flow_summary.dart';
import 'dashboard_expense_group_summary.dart';
import 'dashboard_insight.dart';
import 'dashboard_recommended_action.dart';
import 'dashboard_today_summary.dart';
import 'dashboard_upcoming_operation.dart';

export 'dashboard_action_type.dart';
export 'dashboard_cash_flow_summary.dart';
export 'dashboard_expense_group_summary.dart';
export 'dashboard_insight.dart';
export 'dashboard_insight_type.dart';
export 'dashboard_recommended_action.dart';
export 'dashboard_today_summary.dart';
export 'dashboard_upcoming_operation.dart';

final class DashboardFinancialSummary {
  const DashboardFinancialSummary({
    required this.currencyCode,
    required this.today,
    required this.recordedBalance,
    required this.cashFlow,
    required this.expenseGroups,
    required this.insights,
    required this.upcomingRecurring,
    required this.actions,
  });

  final String currencyCode;
  final DashboardTodaySummary today;
  final double recordedBalance;
  final DashboardCashFlowSummary cashFlow;
  final List<DashboardExpenseGroupSummary> expenseGroups;
  final List<DashboardInsight> insights;
  final List<DashboardUpcomingOperation> upcomingRecurring;
  final List<DashboardRecommendedAction> actions;
}

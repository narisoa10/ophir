import 'dashboard_assistant_summary_presentation.dart';
import 'dashboard_cash_flow_presentation.dart';
import 'dashboard_message_presentation.dart';
import 'dashboard_recorded_balance_presentation.dart';
import 'dashboard_today_presentation.dart';
import 'dashboard_upcoming_presentation.dart';

export 'dashboard_assistant_summary_presentation.dart';
export 'dashboard_cash_flow_presentation.dart';
export 'dashboard_detail_link_presentation.dart';
export 'dashboard_financial_state_detail_presentation.dart';
export 'dashboard_financial_state_presentation.dart';
export 'dashboard_message_presentation.dart';
export 'dashboard_period_distribution_item_presentation.dart';
export 'dashboard_metric_presentation.dart';
export 'dashboard_radar_axis_presentation.dart';
export 'dashboard_radar_presentation.dart';
export 'dashboard_recorded_balance_presentation.dart';
export 'dashboard_today_presentation.dart';
export 'dashboard_upcoming_presentation.dart';

final class DashboardPresentation {
  const DashboardPresentation({
    required this.assistantSummary,
    required this.today,
    required this.recordedBalance,
    required this.cashFlow,
    required this.insights,
    required this.upcoming,
    required this.actions,
  });

  final DashboardAssistantSummaryPresentation assistantSummary;
  final DashboardTodayPresentation today;
  final DashboardRecordedBalancePresentation recordedBalance;
  final DashboardCashFlowPresentation cashFlow;
  final List<DashboardMessagePresentation> insights;
  final List<DashboardUpcomingPresentation> upcoming;
  final List<DashboardMessagePresentation> actions;
}

import 'dashboard_detail_link_presentation.dart';
import 'dashboard_financial_state_presentation.dart';
import 'dashboard_message_presentation.dart';
import 'dashboard_radar_presentation.dart';

final class DashboardAssistantSummaryPresentation {
  const DashboardAssistantSummaryPresentation({
    required this.stateTitle,
    required this.stateDescription,
    required this.financialState,
    required this.radar,
    required this.why,
    required this.whatNext,
    required this.recommendedAction,
    required this.detailLinks,
  });

  final String stateTitle;
  final String stateDescription;
  final DashboardFinancialStatePresentation financialState;
  final DashboardRadarPresentation radar;
  final DashboardMessagePresentation why;
  final DashboardMessagePresentation whatNext;
  final DashboardMessagePresentation recommendedAction;
  final List<DashboardDetailLinkPresentation> detailLinks;
}

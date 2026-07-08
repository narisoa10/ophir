import 'assistant_dashboard_radar_axis.dart';

final class AssistantDashboardRadar {
  const AssistantDashboardRadar({
    required this.axes,
    required this.isLowConfidence,
    required this.evidenceModelIds,
  });

  final List<AssistantDashboardRadarAxis> axes;
  final bool isLowConfidence;
  final List<String> evidenceModelIds;
}

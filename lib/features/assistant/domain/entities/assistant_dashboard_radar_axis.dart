import 'assistant_dashboard_radar_axis_type.dart';

final class AssistantDashboardRadarAxis {
  const AssistantDashboardRadarAxis({
    required this.type,
    required this.value,
    required this.evidenceModelIds,
  });

  final AssistantDashboardRadarAxisType type;
  final double? value;
  final List<String> evidenceModelIds;
}

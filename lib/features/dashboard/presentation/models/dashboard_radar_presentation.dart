import 'dashboard_radar_axis_presentation.dart';

final class DashboardRadarPresentation {
  const DashboardRadarPresentation({
    required this.axes,
    required this.isLowConfidence,
    required this.caption,
  });

  final List<DashboardRadarAxisPresentation> axes;
  final bool isLowConfidence;
  final String caption;
}

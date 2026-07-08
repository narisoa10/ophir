import 'package:flutter/material.dart';

final class DashboardMetricPresentation {
  const DashboardMetricPresentation({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

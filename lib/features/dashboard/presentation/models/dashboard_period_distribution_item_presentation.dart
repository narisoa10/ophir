import 'package:flutter/material.dart';

final class DashboardPeriodDistributionItemPresentation {
  const DashboardPeriodDistributionItemPresentation({
    required this.label,
    required this.amount,
    required this.percent,
    required this.progress,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.hasDetail,
  });

  final String label;
  final String amount;
  final String percent;
  final double progress;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final bool hasDetail;
}

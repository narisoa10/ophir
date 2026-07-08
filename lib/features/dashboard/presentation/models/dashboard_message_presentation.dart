import 'package:flutter/material.dart';

final class DashboardMessagePresentation {
  const DashboardMessagePresentation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

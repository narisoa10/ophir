import 'package:flutter/material.dart';

final class CategoryPresentation {
  const CategoryPresentation({
    required this.name,
    required this.uiGroupName,
    required this.example,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String name;
  final String uiGroupName;
  final String example;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

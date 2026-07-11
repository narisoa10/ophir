import 'package:flutter/material.dart' show Color, IconData;

final class DashboardFinancialStateCategoryContributorPresentation {
  const DashboardFinancialStateCategoryContributorPresentation({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.percentOfIncome,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String categoryId;
  final String name;
  final String amount;
  final String? percentOfIncome;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

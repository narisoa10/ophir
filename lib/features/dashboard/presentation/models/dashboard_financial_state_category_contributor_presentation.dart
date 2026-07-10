import 'package:flutter/material.dart' show Color, IconData;

import '../../../categories/domain/enums/category_financial_distribution_role.dart';
import '../../../categories/domain/enums/spending_pattern.dart';

final class DashboardFinancialStateCategoryContributorPresentation {
  const DashboardFinancialStateCategoryContributorPresentation({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.percentOfIncome,
    required this.percentOfExpenses,
    required this.distributionRole,
    required this.spendingPattern,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String categoryId;
  final String name;
  final String amount;
  final String? percentOfIncome;
  final String? percentOfExpenses;
  final CategoryFinancialDistributionRole distributionRole;
  final SpendingPattern spendingPattern;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

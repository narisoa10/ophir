import 'package:flutter/material.dart';

import 'dashboard_financial_state_detail_presentation.dart';
import 'dashboard_period_distribution_item_presentation.dart';

final class DashboardFinancialStatePresentation {
  const DashboardFinancialStatePresentation({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.stateLabel,
    required this.stateDescription,
    required this.stateIcon,
    required this.stateColor,
    required this.stateBackgroundColor,
    required this.incomeTotalLabel,
    required this.incomeTotalAmount,
    required this.expenseTotalLabel,
    required this.expenseTotalAmount,
    required this.netCashFlowLabel,
    required this.netCashFlowAmount,
    required this.periodLabel,
    required this.detailButtonLabel,
    required this.detail,
  });

  final String title;
  final String subtitle;
  final List<DashboardPeriodDistributionItemPresentation> items;
  final String stateLabel;
  final String stateDescription;
  final IconData stateIcon;
  final Color stateColor;
  final Color stateBackgroundColor;
  final String incomeTotalLabel;
  final String incomeTotalAmount;
  final String expenseTotalLabel;
  final String expenseTotalAmount;
  final String netCashFlowLabel;
  final String netCashFlowAmount;
  final String periodLabel;
  final String detailButtonLabel;
  final DashboardFinancialStateDetailPresentation detail;
}

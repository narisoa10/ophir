import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_metric_row.dart';
import 'dashboard_panel.dart';
import 'dashboard_section.dart';

class DashboardCashFlowDetailContent extends StatelessWidget {
  const DashboardCashFlowDetailContent({
    required this.presentation,
    required this.l10n,
    super.key,
  });

  final DashboardCashFlowPresentation presentation;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: l10n.dashboardCashFlowTitle,
      child: DashboardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardMetricRow(
              label: l10n.dashboardIncomeLabel,
              value: presentation.income,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.sm),
            DashboardMetricRow(
              label: l10n.dashboardExpensesLabel,
              value: presentation.expenses,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            DashboardMetricRow(
              label: l10n.dashboardNetLabel,
              value: presentation.net,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(presentation.summary, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.lg),
            if (presentation.groups.isEmpty)
              Text(l10n.dashboardGroupsEmpty, style: AppTypography.caption)
            else
              ...presentation.groups.map(
                (group) => Padding(
                  padding: AppSpacing.listItemBottomGap,
                  child: DashboardMetricRow(
                    label: group.label,
                    value: group.value,
                    color: group.color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

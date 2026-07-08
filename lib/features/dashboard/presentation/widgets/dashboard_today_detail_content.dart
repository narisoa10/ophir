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

class DashboardTodayDetailContent extends StatelessWidget {
  const DashboardTodayDetailContent({
    required this.presentation,
    required this.l10n,
    super.key,
  });

  final DashboardTodayPresentation presentation;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: l10n.dashboardTodayTitle,
      child: DashboardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(presentation.net, style: AppTypography.screenTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(presentation.summary, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.lg),
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
            const SizedBox(height: AppSpacing.md),
            Text(presentation.operationCount, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

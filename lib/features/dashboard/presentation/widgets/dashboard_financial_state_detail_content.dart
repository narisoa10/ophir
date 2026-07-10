import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_financial_state_l10n.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_financial_plan_section_card.dart';

class DashboardFinancialStateDetailContent extends StatelessWidget {
  const DashboardFinancialStateDetailContent({
    required this.detail,
    required this.contributors,
    super.key,
  });

  final DashboardFinancialStateDetailPresentation detail;
  final Widget contributors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardFinancialPlanSectionCard(
          title: l10n.dashboardFinancialPlanMainProblemTitle,
          initiallyExpanded: true,
          children: [contributors],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        DashboardFinancialPlanSectionCard(
          title: l10n.dashboardFinancialPlanBestEffectTitle,
          initiallyExpanded: false,
          children: [
            Text(
              l10n.dashboardFinancialPlanBestEffectPlaceholder,
              style: AppTypography.body,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        DashboardFinancialPlanSectionCard(
          title: l10n.dashboardFinancialPlanExpectedResultTitle,
          initiallyExpanded: false,
          children: [
            Text(
              l10n.dashboardFinancialPlanExpectedResultPlaceholder,
              style: AppTypography.body,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        DashboardFinancialPlanSectionCard(
          title: l10n.dashboardFinancialPlanRecoveryPlanTitle,
          initiallyExpanded: false,
          children: [
            Text(
              l10n.dashboardFinancialPlanRecoveryPlanPlaceholder,
              style: AppTypography.body,
            ),
          ],
        ),
      ],
    );
  }
}

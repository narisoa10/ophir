import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_panel.dart';
import 'dashboard_section.dart';

class DashboardBalanceDetailContent extends StatelessWidget {
  const DashboardBalanceDetailContent({
    required this.presentation,
    required this.l10n,
    super.key,
  });

  final DashboardRecordedBalancePresentation presentation;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: l10n.dashboardRecordedBalanceTitle,
      child: DashboardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(presentation.amount, style: AppTypography.screenTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(presentation.description, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

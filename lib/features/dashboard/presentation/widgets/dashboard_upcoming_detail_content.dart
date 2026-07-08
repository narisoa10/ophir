import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_panel.dart';
import 'dashboard_section.dart';
import 'dashboard_upcoming_tile.dart';

class DashboardUpcomingDetailContent extends StatelessWidget {
  const DashboardUpcomingDetailContent({
    required this.upcoming,
    required this.l10n,
    super.key,
  });

  final List<DashboardUpcomingPresentation> upcoming;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: l10n.dashboardUpcomingTitle,
      child: DashboardPanel(
        child: upcoming.isEmpty
            ? Text(l10n.dashboardUpcomingEmpty, style: AppTypography.caption)
            : Column(
                children: [
                  for (final item in upcoming) ...[
                    DashboardUpcomingTile(item: item),
                    if (item != upcoming.last)
                      const Divider(
                        color: AppColors.dividerColor,
                        height: AppSpacing.xl,
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

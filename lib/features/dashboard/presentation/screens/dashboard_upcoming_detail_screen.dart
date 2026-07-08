import 'package:flutter/material.dart';

import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../widgets/dashboard_upcoming_detail_content.dart';
import 'dashboard_detail_scaffold.dart';

class DashboardUpcomingDetailScreen extends StatelessWidget {
  const DashboardUpcomingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardDetailScaffold(
      titleBuilder: (l10n) => l10n.dashboardUpcomingTitle,
      contentBuilder: (presentation, l10n) => DashboardUpcomingDetailContent(
        upcoming: presentation.upcoming,
        l10n: l10n,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../widgets/dashboard_insights_detail_content.dart';
import 'dashboard_detail_scaffold.dart';

class DashboardInsightsDetailScreen extends StatelessWidget {
  const DashboardInsightsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardDetailScaffold(
      titleBuilder: (l10n) => l10n.dashboardInsightsTitle,
      contentBuilder: (presentation, l10n) => DashboardInsightsDetailContent(
        messages: presentation.insights,
        l10n: l10n,
      ),
    );
  }
}

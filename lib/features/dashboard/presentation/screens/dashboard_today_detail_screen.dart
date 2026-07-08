import 'package:flutter/material.dart';

import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../widgets/dashboard_today_detail_content.dart';
import 'dashboard_detail_scaffold.dart';

class DashboardTodayDetailScreen extends StatelessWidget {
  const DashboardTodayDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardDetailScaffold(
      titleBuilder: (l10n) => l10n.dashboardTodayTitle,
      contentBuilder: (presentation, l10n) => DashboardTodayDetailContent(
        presentation: presentation.today,
        l10n: l10n,
      ),
    );
  }
}

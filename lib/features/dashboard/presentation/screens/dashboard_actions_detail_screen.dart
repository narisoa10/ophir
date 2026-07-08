import 'package:flutter/material.dart';

import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../widgets/dashboard_actions_detail_content.dart';
import 'dashboard_detail_scaffold.dart';

class DashboardActionsDetailScreen extends StatelessWidget {
  const DashboardActionsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardDetailScaffold(
      titleBuilder: (l10n) => l10n.dashboardActionsTitle,
      contentBuilder: (presentation, l10n) => DashboardActionsDetailContent(
        messages: presentation.actions,
        l10n: l10n,
      ),
    );
  }
}

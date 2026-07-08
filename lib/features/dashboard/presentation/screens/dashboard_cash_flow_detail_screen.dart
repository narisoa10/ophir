import 'package:flutter/material.dart';

import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../widgets/dashboard_cash_flow_detail_content.dart';
import 'dashboard_detail_scaffold.dart';

class DashboardCashFlowDetailScreen extends StatelessWidget {
  const DashboardCashFlowDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardDetailScaffold(
      titleBuilder: (l10n) => l10n.dashboardCashFlowTitle,
      contentBuilder: (presentation, l10n) => DashboardCashFlowDetailContent(
        presentation: presentation.cashFlow,
        l10n: l10n,
      ),
    );
  }
}

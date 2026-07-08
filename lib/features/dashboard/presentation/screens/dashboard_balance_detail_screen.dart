import 'package:flutter/material.dart';

import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../widgets/dashboard_balance_detail_content.dart';
import 'dashboard_detail_scaffold.dart';

class DashboardBalanceDetailScreen extends StatelessWidget {
  const DashboardBalanceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardDetailScaffold(
      titleBuilder: (l10n) => l10n.dashboardRecordedBalanceTitle,
      contentBuilder: (presentation, l10n) => DashboardBalanceDetailContent(
        presentation: presentation.recordedBalance,
        l10n: l10n,
      ),
    );
  }
}

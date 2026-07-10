import 'package:flutter/material.dart';

import '../../../../core/localization/l10n/dashboard_financial_state_l10n.dart';
import '../widgets/dashboard_financial_state_category_contributors_builder.dart';
import '../widgets/dashboard_financial_state_detail_content.dart';
import 'dashboard_detail_scaffold.dart';

class DashboardFinancialStateDetailScreen extends StatelessWidget {
  const DashboardFinancialStateDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardDetailScaffold(
      titleBuilder: (l10n) => l10n.dashboardFinancialStateDetailTitle,
      contentBuilder: (presentation, l10n) {
        return DashboardFinancialStateDetailContent(
          detail: presentation.assistantSummary.financialState.detail,
          contributors:
              const DashboardFinancialStateCategoryContributorsBuilder(),
        );
      },
    );
  }
}

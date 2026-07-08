import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_financial_state_card.dart';

class DashboardV1Content extends StatelessWidget {
  const DashboardV1Content({
    required this.presentation,
    required this.onFinancialStateDetailTap,
    super.key,
  });

  final DashboardPresentation presentation;
  final VoidCallback onFinancialStateDetailTap;

  @override
  Widget build(BuildContext context) {
    final summary = presentation.assistantSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardIncomeDistributionCard(presentation: summary.financialState),
        const SizedBox(height: AppSpacing.sectionGap),
        DashboardFinancialStateCard(
          presentation: summary.financialState,
          onDetailTap: onFinancialStateDetailTap,
        ),
      ],
    );
  }
}

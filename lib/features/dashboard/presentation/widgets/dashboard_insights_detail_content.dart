import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_message_list.dart';
import 'dashboard_section.dart';

class DashboardInsightsDetailContent extends StatelessWidget {
  const DashboardInsightsDetailContent({
    required this.messages,
    required this.l10n,
    super.key,
  });

  final List<DashboardMessagePresentation> messages;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      title: l10n.dashboardInsightsTitle,
      child: DashboardMessageList(
        messages: messages,
        emptyText: l10n.dashboardInsightsEmpty,
      ),
    );
  }
}

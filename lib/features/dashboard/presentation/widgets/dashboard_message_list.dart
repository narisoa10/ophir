import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_message_tile.dart';
import 'dashboard_panel.dart';

class DashboardMessageList extends StatelessWidget {
  const DashboardMessageList({
    required this.messages,
    required this.emptyText,
    super.key,
  });

  final List<DashboardMessagePresentation> messages;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return DashboardPanel(
        child: Text(emptyText, style: AppTypography.caption),
      );
    }

    return Column(
      children: [
        for (final message in messages) ...[
          DashboardMessageTile(message: message),
          if (message != messages.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

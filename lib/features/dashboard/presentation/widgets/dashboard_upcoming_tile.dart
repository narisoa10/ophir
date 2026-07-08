import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';

class DashboardUpcomingTile extends StatelessWidget {
  const DashboardUpcomingTile({required this.item, super.key});

  final DashboardUpcomingPresentation item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppTypography.bodyStrong),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${item.description} - ${item.date}',
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          item.amount,
          style: AppTypography.currencyStrong,
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}

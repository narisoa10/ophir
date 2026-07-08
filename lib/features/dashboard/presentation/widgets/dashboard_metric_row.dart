import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class DashboardMetricRow extends StatelessWidget {
  const DashboardMetricRow({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
    super.key,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          value,
          style: AppTypography.currencyStrong.copyWith(color: color),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}

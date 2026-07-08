import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class DashboardSection extends StatelessWidget {
  const DashboardSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

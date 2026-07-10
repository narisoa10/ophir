import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import 'dashboard_panel.dart';

class DashboardFinancialPlanSectionCard extends StatefulWidget {
  const DashboardFinancialPlanSectionCard({
    required this.title,
    required this.initiallyExpanded,
    required this.children,
    super.key,
  });

  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  State<DashboardFinancialPlanSectionCard> createState() =>
      _DashboardFinancialPlanSectionCardState();
}

class _DashboardFinancialPlanSectionCardState
    extends State<DashboardFinancialPlanSectionCard> {
  late bool _isExpanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      borderRadius: AppRadius.smRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: AppRadius.smRadius,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.sectionTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.iconSecondary,
                  size: AppDimensions.iconMd,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: kThemeAnimationDuration,
          ),
        ],
      ),
    );
  }
}

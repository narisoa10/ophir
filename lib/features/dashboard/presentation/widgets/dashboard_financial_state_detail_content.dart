import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_panel.dart';

class DashboardFinancialStateDetailContent extends StatelessWidget {
  const DashboardFinancialStateDetailContent({required this.detail, super.key});

  final DashboardFinancialStateDetailPresentation detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: detail.currentStateTitle,
          children: [Text(detail.currentStateDescription)],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _Section(
          title: detail.whyTitle,
          children: [Text(detail.whyDescription)],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _Section(
          title: detail.problemsTitle,
          children: [for (final problem in detail.problems) Text(problem)],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _Section(
          title: detail.influenceTitle,
          children: [
            for (final bucket in detail.buckets) _BucketRow(bucket: bucket),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _Section(
          title: detail.recommendationTitle,
          children: [Text(detail.recommendationDescription)],
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _Section(
          title: detail.evidenceTitle,
          children: [for (final evidence in detail.evidence) Text(evidence)],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          DefaultTextStyle.merge(
            style: AppTypography.body,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in children) ...[
                  child,
                  if (child != children.last)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.bucket});

  final DashboardPeriodDistributionItemPresentation bucket;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(
          dimension: AppDimensions.financialStateMetricIconBox,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bucket.backgroundColor,
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(
              bucket.icon,
              color: bucket.color,
              size: AppDimensions.iconSm,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            bucket.label,
            style: AppTypography.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          bucket.percent,
          style: AppTypography.captionStrong.copyWith(color: bucket.color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            bucket.amount,
            style: AppTypography.currencyStrong.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_panel.dart';

class DashboardIncomeDistributionCard extends StatelessWidget {
  const DashboardIncomeDistributionCard({
    required this.presentation,
    super.key,
  });

  final DashboardFinancialStatePresentation presentation;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      borderRadius: AppRadius.cardRadius,
      padding: AppSpacing.compactCardInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(presentation.title, style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(presentation.subtitle, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.financialStateBlockGap),
          for (final item in presentation.items) ...[
            _DistributionRow(item: item),
            if (item != presentation.items.last)
              const SizedBox(height: AppSpacing.financialStateItemGap),
          ],
        ],
      ),
    );
  }
}

class DashboardFinancialStateCard extends StatelessWidget {
  const DashboardFinancialStateCard({
    required this.presentation,
    required this.onDetailTap,
    super.key,
  });

  final DashboardFinancialStatePresentation presentation;
  final VoidCallback onDetailTap;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      padding: AppSpacing.noneInsets,
      borderRadius: AppRadius.cardRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: presentation.stateColor.withValues(
            alpha: AppColors.financialStateCardBackgroundAlpha,
          ),
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: presentation.stateColor.withValues(
              alpha: AppColors.financialStateCardBorderAlpha,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.compactCardInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconBox(
                        icon: presentation.stateIcon,
                        color: presentation.stateColor,
                        backgroundColor: AppColors.transparent,
                        size: AppDimensions.financialStateHeaderIconBox,
                        iconSize: AppDimensions.financialStateHeaderIcon,
                      ),
                      const SizedBox(width: AppSpacing.financialStateBlockGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              presentation.stateLabel,
                              style: AppTypography.sectionTitle.copyWith(
                                color: presentation.stateColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                            const SizedBox(
                              height: AppSpacing.financialStateContentGap,
                            ),
                            Text(
                              presentation.stateDescription,
                              style: AppTypography.financialStateDescription,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.hairline, color: AppColors.border),
            Padding(
              padding: AppSpacing.compactCardInsets,
              child: Column(
                children: [
                  _MetricSummary(
                    metrics: [
                      _MetricData(
                        label: presentation.incomeTotalLabel,
                        amount: presentation.incomeTotalAmount,
                        icon: Icons.south_west,
                        color: AppColors.success,
                        backgroundColor: AppColors.surfaceGreen,
                      ),
                      _MetricData(
                        label: presentation.expenseTotalLabel,
                        amount: presentation.expenseTotalAmount,
                        icon: Icons.north_east,
                        color: AppColors.primary,
                        backgroundColor: AppColors.primaryLight,
                      ),
                      _MetricData(
                        label: presentation.netCashFlowLabel,
                        amount: presentation.netCashFlowAmount,
                        icon: Icons.drag_handle,
                        color: AppColors.chartBlue,
                        backgroundColor: AppColors.surfaceBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.financialStateBlockGap),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onDetailTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: presentation.stateColor,
                        textStyle: AppTypography.button,
                        side: BorderSide(color: presentation.stateColor),
                        shape: AppRadius.buttonShape,
                        padding: AppSpacing.financialStateButtonInsets,
                        minimumSize: const Size(
                          AppSpacing.none,
                          AppDimensions.financialStateButtonHeight,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(presentation.detailButtonLabel),
                          const SizedBox(width: AppSpacing.md),
                          Icon(
                            Icons.chevron_right,
                            color: presentation.stateColor,
                            size: AppDimensions.iconMd,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppSpacing.financialStatePeriodInsets,
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: AppDimensions.iconSm,
                    color: AppColors.iconSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      presentation.periodLabel,
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({required this.item});

  final DashboardPeriodDistributionItemPresentation item;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.financialStateDistributionMinHeight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _IconBox(
            icon: item.icon,
            color: item.color,
            backgroundColor: item.backgroundColor,
            size: AppDimensions.financialStateDistributionIconBox,
            iconSize: AppDimensions.financialStateDistributionIcon,
          ),
          const SizedBox(width: AppSpacing.financialStateBlockGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: AppTypography.distributionLabel,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.amount,
                        style: AppTypography.distributionValue,
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.financialStateBlockGap),
                    Text(item.percent, style: AppTypography.distributionValue),
                  ],
                ),
                const SizedBox(height: AppSpacing.financialStateContentGap),
                _DistributionProgress(item: item),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionProgress extends StatelessWidget {
  const _DistributionProgress({required this.item});

  final DashboardPeriodDistributionItemPresentation item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final progress = item.progress.clamp(0.0, 1.0).toDouble();

        return SizedBox(
          height: AppDimensions.financialStateDistributionProgressHeight,
          child: ClipRRect(
            borderRadius: AppRadius.smRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.progressTrack),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    heightFactor: 1,
                    child: ColoredBox(color: item.color),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: AppDimensions.financialStateMetricDividerHeight,
      child: VerticalDivider(
        width: AppSpacing.md,
        thickness: AppDimensions.financialStateDividerThickness,
        color: AppColors.border,
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <
            AppDimensions.financialStateMetricCompactBreakpoint) {
          return Column(
            children: [
              for (final metric in metrics) ...[
                _MetricCompactTile(metric: metric),
                if (metric != metrics.last)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final metric in metrics) ...[
              Expanded(child: _MetricTile(metric: metric)),
              if (metric != metrics.last) ...[
                const _MetricDivider(),
                const SizedBox(width: AppSpacing.md),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(
          icon: metric.icon,
          color: metric.color,
          backgroundColor: metric.backgroundColor,
          size: AppDimensions.financialStateMetricIconBox,
          iconSize: AppDimensions.financialStateMetricIcon,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: AppTypography.financialStateMetricLabel,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                metric.amount,
                style: AppTypography.financialStateAmount.copyWith(
                  color: metric.color,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCompactTile extends StatelessWidget {
  const _MetricCompactTile({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _IconBox(
          icon: metric.icon,
          color: metric.color,
          backgroundColor: metric.backgroundColor,
          size: AppDimensions.financialStateMetricIconBox,
          iconSize: AppDimensions.financialStateMetricIcon,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                metric.label,
                style: AppTypography.financialStateMetricLabel,
                softWrap: true,
              ),
              Text(
                metric.amount,
                style: AppTypography.financialStateAmount.copyWith(
                  color: metric.color,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.size = AppDimensions.financialStateIconBox,
    this.iconSize = AppDimensions.iconLg,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.smRadius,
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}

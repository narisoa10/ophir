import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_assistant_l10n.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_panel.dart';

class DashboardFinancialRadar extends StatelessWidget {
  const DashboardFinancialRadar({required this.radar, super.key});

  final DashboardRadarPresentation radar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dashboardRadarTitle,
                  style: AppTypography.sectionTitle,
                ),
              ),
              if (radar.isLowConfidence)
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceBlue,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      l10n.dashboardLowConfidenceLabel,
                      style: AppTypography.captionStrong.copyWith(
                        color: AppColors.chartBlue,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 168,
            child: Row(
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: CustomPaint(painter: _RadarPainter(axes: radar.axes)),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final axis in radar.axes) ...[
                        _AxisRow(axis: axis),
                        if (axis != radar.axes.last)
                          const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(radar.caption, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _AxisRow extends StatelessWidget {
  const _AxisRow({required this.axis});

  final DashboardRadarAxisPresentation axis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            axis.label,
            style: AppTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 52,
          child: LinearProgressIndicator(
            value: axis.isAvailable ? axis.value : 0,
            minHeight: 6,
            color: axis.isAvailable ? AppColors.primary : AppColors.border,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.axes});

  final List<DashboardRadarAxisPresentation> axes;

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.isEmpty) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final gridPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final scale in const [0.33, 0.66, 1.0]) {
      canvas.drawPath(_polygon(center, radius * scale, null), gridPaint);
    }

    for (var index = 0; index < axes.length; index++) {
      final point = _point(center, radius, index, axes.length);
      canvas.drawLine(center, point, axisPaint);
    }

    final available = axes.where((axis) => axis.isAvailable).length;
    if (available < 3) {
      return;
    }

    final valuePath = _polygon(
      center,
      radius,
      (index) => axes[index].value.clamp(0, 1),
    );
    canvas.drawPath(valuePath, fillPaint);
    canvas.drawPath(valuePath, strokePaint);
  }

  Path _polygon(
    Offset center,
    double radius,
    double Function(int index)? valueBuilder,
  ) {
    final path = Path();
    for (var index = 0; index < axes.length; index++) {
      final value = valueBuilder?.call(index) ?? 1;
      final point = _point(center, radius * value, index, axes.length);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Offset _point(Offset center, double radius, int index, int count) {
    final angle = (-math.pi / 2) + (index * 2 * math.pi / count);
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.axes != axes;
  }
}

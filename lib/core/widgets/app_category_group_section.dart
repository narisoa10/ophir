import 'package:flutter/material.dart';

import '../theme_v1/app_theme_colors.dart';
import '../theme_v1/app_spacing.dart';

class AppCategoryGroupSection extends StatelessWidget {
  const AppCategoryGroupSection({
    required this.isExpanded,
    required this.children,
    required this.header,
    this.showChildConnector = false,
    super.key,
  });

  final bool isExpanded;
  final List<Widget> children;
  final bool showChildConnector;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.lg),
          Column(children: _spacedChildren()),
        ],
      ],
    );
    return content;
  }

  List<Widget> _spacedChildren() {
    return [
      for (final child in children.indexed) ...[
        if (showChildConnector)
          _CategoryGroupChildRow(
            isLast: child.$1 == children.length - 1,
            child: child.$2,
          )
        else
          child.$2,
        if (child.$1 < children.length - 1)
          const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }
}

class _CategoryGroupChildRow extends StatelessWidget {
  const _CategoryGroupChildRow({required this.isLast, required this.child});

  final bool isLast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSpacing.xxxl,
            child: CustomPaint(
              painter: _CategoryGroupChildConnectorPainter(
                isLast: isLast,
                color: context.appThemeColors.divider,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CategoryGroupChildConnectorPainter extends CustomPainter {
  const _CategoryGroupChildConnectorPainter({
    required this.isLast,
    required this.color,
  });

  final bool isLast;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = AppSpacing.hairline
      ..strokeCap = StrokeCap.round;
    final lineX = size.width / 2;
    final branchY = size.height / 2;

    canvas.drawLine(
      Offset(lineX, 0),
      Offset(lineX, isLast ? branchY : size.height),
      paint,
    );
    canvas.drawLine(Offset(lineX, branchY), Offset(size.width, branchY), paint);
  }

  @override
  bool shouldRepaint(_CategoryGroupChildConnectorPainter oldDelegate) {
    return oldDelegate.isLast != isLast || oldDelegate.color != color;
  }
}

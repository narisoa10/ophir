import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_radius.dart';

class OperationIconBadge extends StatelessWidget {
  const OperationIconBadge({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.backgroundColor,
    super.key,
  });

  final double size;
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.smRadius,
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
}

import 'package:flutter/material.dart';

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
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}

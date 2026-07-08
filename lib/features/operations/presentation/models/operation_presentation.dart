import 'package:flutter/material.dart';

import '../../domain/entities/operation.dart';

final class OperationPresentation {
  const OperationPresentation({
    required this.operation,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final Operation operation;
  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

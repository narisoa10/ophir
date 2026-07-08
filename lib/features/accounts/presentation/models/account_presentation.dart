import 'package:flutter/material.dart';

final class AccountPresentation {
  const AccountPresentation({
    required this.name,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String name;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}
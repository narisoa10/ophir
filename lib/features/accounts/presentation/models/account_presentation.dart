import 'package:flutter/material.dart';

final class AccountPresentation {
  const AccountPresentation({required this.name, this.icon, this.colorKey});

  final String name;
  final IconData? icon;
  final String? colorKey;
}

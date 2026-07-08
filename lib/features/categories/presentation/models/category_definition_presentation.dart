import 'package:flutter/material.dart';

import '../../domain/enums/category_type.dart';

final class CategoryDefinitionPresentation {
  const CategoryDefinitionPresentation({
    required this.stableKey,
    required this.name,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.type,
    required this.sortOrder,
  });

  final String stableKey;
  final String name;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final CategoryType type;
  final int sortOrder;
}

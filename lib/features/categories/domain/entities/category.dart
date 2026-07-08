import 'package:flutter/foundation.dart' show immutable;

import '../enums/category_analytics_group.dart';
import '../enums/category_type.dart';
import '../enums/category_ui_group.dart';

@immutable
final class Category {
  const Category({
    required this.id,
    required this.type,
    required this.uiGroup,
    required this.analyticsGroup,
    required this.nameKey,
    required this.iconKey,
    required this.colorKey,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.exampleKey,
    this.stableKey,
  });

  final String id;
  final CategoryType type;
  final CategoryUiGroup uiGroup;
  final CategoryAnalyticsGroup analyticsGroup;
  final String nameKey;
  final String iconKey;
  final String colorKey;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String exampleKey;
  final String? stableKey;
}

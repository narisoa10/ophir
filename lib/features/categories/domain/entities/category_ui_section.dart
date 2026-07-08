import 'package:flutter/foundation.dart' show immutable;

import '../enums/category_ui_group.dart';
import 'category.dart';

@immutable
final class CategoryUiSection {
  const CategoryUiSection({required this.group, required this.categories});

  final CategoryUiGroup group;
  final List<Category> categories;
}

import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/models/category_presentation.dart';
import 'operation_category_compact_tile.dart';

class OperationCategorySection extends StatelessWidget {
  const OperationCategorySection({
    required this.title,
    required this.categories,
    required this.presentationBuilder,
    required this.onCategorySelected,
    super.key,
  });

  final String title;
  final List<Category> categories;
  final CategoryPresentation Function(Category category) presentationBuilder;
  final ValueChanged<Category> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.categoryPickerSectionInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.categoryHeaderGap),
          Wrap(
            spacing: AppSpacing.categoryChipGap,
            runSpacing: AppSpacing.categoryChipGap,
            children: [
              for (final category in categories)
                OperationCategoryCompactTile(
                  category: presentationBuilder(category),
                  onTap: () => onCategorySelected(category),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

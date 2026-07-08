import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/adapters/category_group_adapter.dart';
import '../../../categories/presentation/adapters/category_presentation_adapters.dart';
import '../models/operation_category_section_data.dart';
import 'operation_category_section.dart';

class OperationCategorySectionList extends StatelessWidget {
  const OperationCategorySectionList({
    required this.sections,
    required this.onCategorySelected,
    super.key,
  });

  final List<OperationCategorySectionData> sections;
  final ValueChanged<Category> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const categoryAdapter = CategoryAdapter();
    const groupAdapter = CategoryGroupAdapter();

    return ListView.separated(
      padding: AppSpacing.categoryPickerScreenInsets,
      itemCount: sections.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: AppSpacing.categorySectionGap);
      },
      itemBuilder: (context, index) {
        final section = sections[index];

        return OperationCategorySection(
          title: groupAdapter.label(section.group, l10n),
          categories: section.categories,
          presentationBuilder: (category) {
            return categoryAdapter.toPresentation(category, l10n);
          },
          onCategorySelected: onCategorySelected,
        );
      },
    );
  }
}

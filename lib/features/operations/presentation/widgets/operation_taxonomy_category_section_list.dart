import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/models/category_picker_taxonomy_section.dart';
import 'operation_taxonomy_category_section.dart';

class OperationTaxonomyCategorySectionList extends StatefulWidget {
  const OperationTaxonomyCategorySectionList({
    required this.sections,
    required this.onCategorySelected,
    super.key,
  });

  final List<CategoryPickerTaxonomySection> sections;
  final ValueChanged<Category> onCategorySelected;

  @override
  State<OperationTaxonomyCategorySectionList> createState() =>
      _OperationTaxonomyCategorySectionListState();
}

class _OperationTaxonomyCategorySectionListState
    extends State<OperationTaxonomyCategorySectionList> {
  String? _expandedGroupKey;

  void _setExpandedGroup(String groupKey, bool isExpanded) {
    setState(() {
      _expandedGroupKey = isExpanded ? groupKey : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.categoryPickerScreenInsets,
      itemCount: widget.sections.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: AppSpacing.categorySectionGap);
      },
      itemBuilder: (context, index) {
        final section = widget.sections[index];
        final groupKey = section.group.key;

        return OperationTaxonomyCategorySection(
          section: section,
          isExpanded: _expandedGroupKey == groupKey,
          onExpansionChanged: (isExpanded) {
            _setExpandedGroup(groupKey, isExpanded);
          },
          onItemSelected: (item) {
            widget.onCategorySelected(item.legacyCategory);
          },
        );
      },
    );
  }
}

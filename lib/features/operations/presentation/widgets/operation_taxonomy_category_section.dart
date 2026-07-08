import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../categories/presentation/models/category_picker_taxonomy_item.dart';
import '../../../categories/presentation/models/category_picker_taxonomy_section.dart';
import 'operation_taxonomy_category_tile.dart';

class OperationTaxonomyCategorySection extends StatelessWidget {
  const OperationTaxonomyCategorySection({
    required this.section,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onItemSelected,
    super.key,
  });

  final CategoryPickerTaxonomySection section;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<CategoryPickerTaxonomyItem> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.smRadius,
          ),
          child: InkWell(
            borderRadius: AppRadius.smRadius,
            onTap: () => onExpansionChanged(!isExpanded),
            child: Padding(
              padding: AppSpacing.listTileInsets,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      section.group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong,
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? AppIcons.actionChevronDown
                        : AppIcons.actionChevronRight,
                    color: AppColors.iconTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: kThemeAnimationDuration,
          curve: Curves.easeInOut,
          child: isExpanded
              ? Padding(
                  padding: AppSpacing.categoryPickerSectionInsets,
                  child: Column(
                    children: [
                      for (final item in section.items)
                        Padding(
                          padding: AppSpacing.listItemBottomGap,
                          child: OperationTaxonomyCategoryTile(
                            item: item,
                            onTap: () => onItemSelected(item),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

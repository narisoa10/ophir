import 'category_group_presentation.dart';
import 'category_picker_taxonomy_item.dart';

final class CategoryPickerTaxonomySection {
  const CategoryPickerTaxonomySection({
    required this.group,
    required this.items,
  });

  final CategoryGroupPresentation group;
  final List<CategoryPickerTaxonomyItem> items;
}

import '../enums/category_ui_group.dart';
import 'category.dart';
import 'category_ui_section.dart';

final class CategoryUiSectionResolver {
  const CategoryUiSectionResolver();

  List<CategoryUiSection> resolve(List<Category> categories) {
    final sections = <CategoryUiGroup, List<Category>>{};

    for (final category in categories) {
      sections.putIfAbsent(category.uiGroup, () => []).add(category);
    }

    return CategoryUiGroup.values
        .where(sections.containsKey)
        .map(
          (group) => CategoryUiSection(
            group: group,
            categories: sections[group] ?? const <Category>[],
          ),
        )
        .toList(growable: false);
  }
}

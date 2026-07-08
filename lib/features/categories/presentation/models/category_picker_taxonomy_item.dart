import '../../domain/entities/category.dart';
import '../../domain/entities/category_definition.dart';
import 'category_definition_presentation.dart';

final class CategoryPickerTaxonomyItem {
  const CategoryPickerTaxonomyItem({
    required this.legacyCategory,
    required this.definition,
    required this.presentation,
  });

  final Category legacyCategory;
  final CategoryDefinition definition;
  final CategoryDefinitionPresentation presentation;
}

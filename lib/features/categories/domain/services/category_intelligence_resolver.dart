import '../entities/category.dart';
import '../entities/category_intelligence_catalog.dart';
import '../entities/category_intelligence_profile.dart';
import '../entities/legacy_category_bridge.dart';

final class CategoryIntelligenceResolver {
  const CategoryIntelligenceResolver({
    LegacyCategoryBridge bridge = const LegacyCategoryBridge(),
  }) : _bridge = bridge;

  final LegacyCategoryBridge _bridge;

  CategoryIntelligenceProfile? profileFor(Category category) {
    final definition = _bridge.definitionFor(category);

    if (definition == null) {
      return null;
    }

    return CategoryIntelligenceCatalog.profileFor(definition.key);
  }
}

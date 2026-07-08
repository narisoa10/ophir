import '../../domain/entities/category.dart';
import '../../domain/entities/category_group_resolver.dart';
import '../../domain/enums/category_type.dart';
import '../dto/category_dto.dart';

extension CategoryDtoMapper on CategoryDto {
  Category toEntity() {
    const groupResolver = CategoryGroupResolver();

    return Category(
      id: id,
      type: CategoryType.fromJson(type),
      uiGroup: groupResolver.resolveUiGroup(
        nameKey: nameKey,
        legacyGroupKey: groupKey,
      ),
      analyticsGroup: groupResolver.resolveAnalyticsGroup(
        nameKey: nameKey,
        legacyGroupKey: groupKey,
      ),
      nameKey: nameKey,
      iconKey: iconKey,
      colorKey: colorKey,
      sortOrder: sortOrder,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      exampleKey: exampleKey,
      stableKey: stableKey,
    );
  }
}

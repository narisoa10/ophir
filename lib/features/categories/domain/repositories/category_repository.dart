import '../../../../core/errors/result.dart';
import '../entities/category.dart';
import '../enums/category_type.dart';

abstract interface class CategoryRepository {
  Future<Result<List<Category>>> getCategories();

  Future<Result<List<Category>>> getCategoriesByType(CategoryType type);

  Future<Result<List<Category>>> getTaxonomyCategoriesByType(CategoryType type);

  Future<Result<List<Category>>> getCategoriesByIds(Set<String> ids);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/category.dart';
import '../domain/enums/category_type.dart';
import 'category_providers.dart';

final categoryControllerProvider =
AsyncNotifierProvider<CategoryController, Result<List<Category>>>(
  CategoryController.new,
);

final class CategoryController
    extends AsyncNotifier<Result<List<Category>>> {
  @override
  Future<Result<List<Category>>> build() async {
    final repository = ref.watch(categoryRepositoryProvider);
    return repository.getCategories();
  }

  Future<void> loadByType(CategoryType type) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(categoryRepositoryProvider);
      return repository.getCategoriesByType(type);
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(categoryRepositoryProvider);
      return repository.getCategories();
    });
  }
}
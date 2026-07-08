import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../data/repositories/supabase_category_repository.dart';
import '../domain/entities/category.dart';
import '../domain/entities/category_ui_section.dart';
import '../domain/entities/category_ui_section_resolver.dart';
import '../domain/enums/category_type.dart';
import '../domain/repositories/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return SupabaseCategoryRepository(Supabase.instance.client);
});

final categoriesProvider = FutureProvider<Result<List<Category>>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategories();
});

final expenseCategoriesProvider = FutureProvider<Result<List<Category>>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategoriesByType(CategoryType.expense);
});

final incomeCategoriesProvider = FutureProvider<Result<List<Category>>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategoriesByType(CategoryType.income);
});

final expenseTaxonomyCategoriesProvider =
    FutureProvider<Result<List<Category>>>((ref) {
      final repository = ref.watch(categoryRepositoryProvider);
      return repository.getTaxonomyCategoriesByType(CategoryType.expense);
    });

final incomeTaxonomyCategoriesProvider = FutureProvider<Result<List<Category>>>(
  (ref) {
    final repository = ref.watch(categoryRepositoryProvider);
    return repository.getTaxonomyCategoriesByType(CategoryType.income);
  },
);

final expenseCategoryUiSectionsProvider =
    FutureProvider<Result<List<CategoryUiSection>>>((ref) async {
      final result = await ref.watch(expenseCategoriesProvider.future);
      return _toUiSections(result);
    });

final incomeCategoryUiSectionsProvider =
    FutureProvider<Result<List<CategoryUiSection>>>((ref) async {
      final result = await ref.watch(incomeCategoriesProvider.future);
      return _toUiSections(result);
    });

Result<List<CategoryUiSection>> _toUiSections(Result<List<Category>> result) {
  return switch (result) {
    Success<List<Category>>(:final value) => Success(
      const CategoryUiSectionResolver().resolve(value),
    ),
    Failure<List<Category>>(:final failure) => Failure(failure),
  };
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_type.dart';
import '../../domain/repositories/category_repository.dart';
import '../dto/category_dto.dart';
import '../mappers/category_mapper.dart';

final class SupabaseCategoryRepository implements CategoryRepository {
  const SupabaseCategoryRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'categories';

  @override
  Future<Result<List<Category>>> getCategories() async {
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .order('sort_order');

      final categories = data
          .map((json) => CategoryDto.fromJson(json).toEntity())
          .toList(growable: false);

      return Success(categories);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<List<Category>>> getCategoriesByType(CategoryType type) async {
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('type', type.toJson())
          .eq('is_active', true)
          .order('sort_order');

      final categories = data
          .map((json) => CategoryDto.fromJson(json).toEntity())
          .toList(growable: false);

      return Success(categories);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<List<Category>>> getTaxonomyCategoriesByType(
    CategoryType type,
  ) async {
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('type', type.toJson())
          .not('stable_key', 'is', null)
          .order('sort_order');

      final categories = data
          .map((json) => CategoryDto.fromJson(json).toEntity())
          .toList(growable: false);

      return Success(categories);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<Result<List<Category>>> getCategoriesByIds(Set<String> ids) async {
    if (ids.isEmpty) {
      return const Success([]);
    }

    try {
      final data = await _client
          .from(_table)
          .select()
          .inFilter('id', ids.toList(growable: false))
          .order('sort_order');

      final categories = data
          .map((json) => CategoryDto.fromJson(json).toEntity())
          .toList(growable: false);

      return Success(categories);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }
}

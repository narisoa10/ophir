import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../categories/controller/category_providers.dart';
import '../../categories/domain/entities/category.dart';
import '../domain/entities/operation.dart';
import 'operation_providers.dart';

final operationDisplayCategoriesProvider =
    FutureProvider<Result<List<Category>>>((ref) async {
      final operationsResult = await ref.watch(operationsProvider.future);

      return switch (operationsResult) {
        Success<List<Operation>>(:final value) => _categoriesForOperations(
          ref,
          value,
        ),
        Failure<List<Operation>>(:final failure) => Failure(failure),
      };
    });

Future<Result<List<Category>>> _categoriesForOperations(
  Ref ref,
  List<Operation> operations,
) {
  final categoryIds = operations
      .map((operation) => operation.categoryId)
      .whereType<String>()
      .toSet();

  if (categoryIds.isEmpty) {
    return Future.value(const Success([]));
  }

  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategoriesByIds(categoryIds);
}

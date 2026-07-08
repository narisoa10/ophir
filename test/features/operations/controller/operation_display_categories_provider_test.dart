import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/categories/controller/category_providers.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/repositories/category_repository.dart';
import 'package:ophir/features/operations/controller/operation_display_categories_provider.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';

void main() {
  group('operationDisplayCategoriesProvider', () {
    test('loads referenced inactive taxonomy categories by id', () async {
      final category = _category(
        id: 'internet',
        stableKey: 'expense.housing.internet',
        isActive: false,
      );
      final categoryRepository = _FakeCategoryRepository(
        categories: [category],
      );
      final operationRepository = _FakeOperationRepository(
        operations: [_operation(id: 'operation', categoryId: 'internet')],
      );
      final container = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(categoryRepository),
          operationRepositoryProvider.overrideWithValue(operationRepository),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        operationDisplayCategoriesProvider.future,
      );

      final categories = switch (result) {
        Success<List<Category>>(:final value) => value,
        Failure<List<Category>>() => fail('Expected display categories'),
      };

      expect(categoryRepository.requestedIds, {'internet'});
      expect(categories, hasLength(1));
      expect(categories.single.id, 'internet');
      expect(categories.single.isActive, isFalse);
      expect(categories.single.stableKey, 'expense.housing.internet');
    });
  });
}

final class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({required this.categories});

  final List<Category> categories;
  Set<String> requestedIds = const {};

  @override
  Future<Result<List<Category>>> getCategories() async {
    return const Success([]);
  }

  @override
  Future<Result<List<Category>>> getCategoriesByType(CategoryType type) async {
    return const Success([]);
  }

  @override
  Future<Result<List<Category>>> getTaxonomyCategoriesByType(
    CategoryType type,
  ) async {
    return const Success([]);
  }

  @override
  Future<Result<List<Category>>> getCategoriesByIds(Set<String> ids) async {
    requestedIds = ids;
    return Success(
      categories
          .where((category) => ids.contains(category.id))
          .toList(growable: false),
    );
  }
}

final class _FakeOperationRepository implements OperationRepository {
  const _FakeOperationRepository({required this.operations});

  final List<Operation> operations;

  @override
  Future<Result<List<Operation>>> getOperations() async {
    return Success(operations);
  }

  @override
  Future<Result<Operation>> createOperation(Operation operation) async {
    return Success(operation);
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    return Success(operation);
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) async {
    return const Success(null);
  }
}

Category _category({
  required String id,
  String? stableKey,
  bool isActive = true,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: CategoryType.expense,
    uiGroup: CategoryUiGroup.dailyLife,
    analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
    nameKey: 'categoryTaxonomyExpenseHousingInternetName',
    iconKey: 'housing',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey,
  );
}

Operation _operation({required String id, String? categoryId}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: id,
    userId: 'user',
    type: OperationType.expense,
    amount: 42,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
  );
}

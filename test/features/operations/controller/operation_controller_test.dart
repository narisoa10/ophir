import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/categories/controller/category_providers.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/repositories/category_repository.dart';
import 'package:ophir/features/operations/controller/operation_controller.dart';
import 'package:ophir/features/operations/controller/operation_display_categories_provider.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/operations/domain/repositories/operation_repository.dart';

void main() {
  group('OperationController', () {
    test('create invalidates operationsProvider path', () async {
      final repository = _FakeOperationRepository(operations: []);
      final container = _container(operationRepository: repository);
      addTearDown(container.dispose);

      expect(
        _operationsFrom(await container.read(operationsProvider.future)),
        isEmpty,
      );

      await container
          .read(operationControllerProvider.notifier)
          .createOperation(_operation(id: 'created', amount: 10));

      final operations = _operationsFrom(
        await container.read(operationsProvider.future),
      );

      expect(operations.map((operation) => operation.id), ['created']);
    });

    test('update invalidates operationsProvider path', () async {
      final repository = _FakeOperationRepository(
        operations: [_operation(id: 'updated', amount: 10)],
      );
      final container = _container(operationRepository: repository);
      addTearDown(container.dispose);

      expect(
        _operationsFrom(
          await container.read(operationsProvider.future),
        ).single.amount,
        10,
      );

      await container
          .read(operationControllerProvider.notifier)
          .updateOperation(_operation(id: 'updated', amount: 100));

      final operations = _operationsFrom(
        await container.read(operationsProvider.future),
      );

      expect(operations.single.amount, 100);
    });

    test('archive invalidates operationsProvider path', () async {
      final repository = _FakeOperationRepository(
        operations: [_operation(id: 'archived', amount: 10)],
      );
      final container = _container(operationRepository: repository);
      addTearDown(container.dispose);

      expect(
        _operationsFrom(await container.read(operationsProvider.future)),
        hasLength(1),
      );

      await container
          .read(operationControllerProvider.notifier)
          .archiveOperation('archived');

      expect(
        _operationsFrom(await container.read(operationsProvider.future)),
        isEmpty,
      );
    });

    test(
      'create invalidates operationDisplayCategoriesProvider path',
      () async {
        final category = _category(id: 'rent');
        final repository = _FakeOperationRepository(operations: []);
        final container = _container(
          operationRepository: repository,
          categories: [category],
        );
        addTearDown(container.dispose);

        expect(
          _categoriesFrom(
            await container.read(operationDisplayCategoriesProvider.future),
          ),
          isEmpty,
        );

        await container
            .read(operationControllerProvider.notifier)
            .createOperation(
              _operation(id: 'created', amount: 10, categoryId: category.id),
            );

        final categories = _categoriesFrom(
          await container.read(operationDisplayCategoriesProvider.future),
        );

        expect(categories.map((category) => category.id), ['rent']);
      },
    );
  });
}

ProviderContainer _container({
  required _FakeOperationRepository operationRepository,
  List<Category> categories = const [],
}) {
  return ProviderContainer(
    overrides: [
      operationRepositoryProvider.overrideWithValue(operationRepository),
      categoryRepositoryProvider.overrideWithValue(
        _FakeCategoryRepository(categories: categories),
      ),
    ],
  );
}

final class _FakeOperationRepository implements OperationRepository {
  _FakeOperationRepository({required List<Operation> operations})
    : _operations = [...operations];

  final List<Operation> _operations;

  @override
  Future<Result<List<Operation>>> getOperations() async {
    return Success(List.unmodifiable(_operations));
  }

  @override
  Future<Result<Operation>> createOperation(Operation operation) async {
    _operations.add(operation);
    return Success(operation);
  }

  @override
  Future<Result<Operation>> updateOperation(Operation operation) async {
    final index = _operations.indexWhere((item) => item.id == operation.id);
    if (index >= 0) {
      _operations[index] = operation;
    } else {
      _operations.add(operation);
    }
    return Success(operation);
  }

  @override
  Future<Result<void>> archiveOperation(String operationId) async {
    _operations.removeWhere((operation) => operation.id == operationId);
    return const Success(null);
  }
}

final class _FakeCategoryRepository implements CategoryRepository {
  const _FakeCategoryRepository({required this.categories});

  final List<Category> categories;

  @override
  Future<Result<List<Category>>> getCategories() async {
    return Success(categories.where((category) => category.isActive).toList());
  }

  @override
  Future<Result<List<Category>>> getCategoriesByType(CategoryType type) async {
    return Success(
      categories
          .where((category) => category.type == type && category.isActive)
          .toList(growable: false),
    );
  }

  @override
  Future<Result<List<Category>>> getTaxonomyCategoriesByType(
    CategoryType type,
  ) async {
    return Success(
      categories
          .where(
            (category) => category.type == type && category.stableKey != null,
          )
          .toList(growable: false),
    );
  }

  @override
  Future<Result<List<Category>>> getCategoriesByIds(Set<String> ids) async {
    return Success(
      categories
          .where((category) => ids.contains(category.id))
          .toList(growable: false),
    );
  }
}

List<Operation> _operationsFrom(Result<List<Operation>> result) {
  return switch (result) {
    Success<List<Operation>>(:final value) => value,
    Failure<List<Operation>>() => fail('Expected operations'),
  };
}

List<Category> _categoriesFrom(Result<List<Category>> result) {
  return switch (result) {
    Success<List<Category>>(:final value) => value,
    Failure<List<Category>>() => fail('Expected categories'),
  };
}

Category _category({required String id}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: CategoryType.expense,
    uiGroup: CategoryUiGroup.housing,
    analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
    nameKey: 'categoryTaxonomyExpenseHousingRentName',
    iconKey: 'housing',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: 'expense.housing.rent',
  );
}

Operation _operation({
  required String id,
  required double amount,
  String? categoryId,
}) {
  final now = DateTime.utc(2026);

  return Operation(
    id: id,
    userId: 'user',
    categoryId: categoryId,
    type: OperationType.expense,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
  );
}

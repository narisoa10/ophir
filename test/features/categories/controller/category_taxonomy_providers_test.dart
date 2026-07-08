import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/localization/generated/app_localizations_en.dart';
import 'package:ophir/features/categories/controller/category_picker_taxonomy_providers.dart';
import 'package:ophir/features/categories/controller/category_providers.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/repositories/category_repository.dart';

void main() {
  group('category taxonomy providers', () {
    test('legacy provider keeps using active-only category method', () async {
      final repository = _FakeCategoryRepository();
      final container = ProviderContainer(
        overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(expenseCategoriesProvider.future);

      expect(repository.getCategoriesByTypeCalls, 1);
      expect(repository.getTaxonomyCategoriesByTypeCalls, 0);
    });

    test('taxonomy provider uses taxonomy category method', () async {
      final repository = _FakeCategoryRepository(
        taxonomyExpenseCategories: [
          _category(
            id: 'internet',
            type: CategoryType.expense,
            nameKey: 'categoryTaxonomyExpenseHousingInternetName',
            stableKey: 'expense.housing.internet',
            isActive: false,
          ),
          _category(
            id: 'broad',
            type: CategoryType.expense,
            nameKey: 'categoryUtilities',
            stableKey: null,
            isActive: true,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        expenseCategoryPickerTaxonomySectionsProvider(
          AppLocalizationsEn(),
        ).future,
      );

      expect(repository.getCategoriesByTypeCalls, 0);
      expect(repository.getTaxonomyCategoriesByTypeCalls, 1);
      final sections = switch (result) {
        Success(value: final value) => value,
        Failure() => fail('Expected taxonomy sections'),
      };
      expect(sections, hasLength(1));
      expect(sections.single.items.single.legacyCategory.id, 'internet');
    });
  });
}

final class _FakeCategoryRepository implements CategoryRepository {
  _FakeCategoryRepository({this.taxonomyExpenseCategories = const []});

  final List<Category> taxonomyExpenseCategories;
  int getCategoriesByTypeCalls = 0;
  int getTaxonomyCategoriesByTypeCalls = 0;
  int getCategoriesByIdsCalls = 0;

  @override
  Future<Result<List<Category>>> getCategories() async {
    return const Success([]);
  }

  @override
  Future<Result<List<Category>>> getCategoriesByType(CategoryType type) async {
    getCategoriesByTypeCalls += 1;
    return const Success([]);
  }

  @override
  Future<Result<List<Category>>> getTaxonomyCategoriesByType(
    CategoryType type,
  ) async {
    getTaxonomyCategoriesByTypeCalls += 1;
    return Success(switch (type) {
      CategoryType.expense => taxonomyExpenseCategories,
      CategoryType.income => const [],
    });
  }

  @override
  Future<Result<List<Category>>> getCategoriesByIds(Set<String> ids) async {
    getCategoriesByIdsCalls += 1;
    return const Success([]);
  }
}

Category _category({
  required String id,
  required CategoryType type,
  required String nameKey,
  String? stableKey,
  required bool isActive,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: type,
    uiGroup: type == CategoryType.income
        ? CategoryUiGroup.income
        : CategoryUiGroup.dailyLife,
    analyticsGroup: type == CategoryType.income
        ? CategoryAnalyticsGroup.income
        : CategoryAnalyticsGroup.flexibleExpenses,
    nameKey: nameKey,
    iconKey: 'other',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey,
  );
}

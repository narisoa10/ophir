import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/localization/generated/app_localizations_en.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/domain/enums/expense_category_group.dart';
import 'package:ophir/features/categories/domain/enums/income_category_group.dart';
import 'package:ophir/features/categories/presentation/adapters/category_picker_taxonomy_adapter.dart';

void main() {
  const adapter = CategoryPickerTaxonomyAdapter();
  final l10n = AppLocalizationsEn();

  group('CategoryPickerTaxonomyAdapter', () {
    test('keeps expense and income taxonomy trees separate', () {
      final legacyCategories = [
        _category(
          id: 'expense-rent',
          type: CategoryType.expense,
          nameKey: 'categoryRent',
        ),
        _category(
          id: 'income-salary',
          type: CategoryType.income,
          nameKey: 'categorySalary',
        ),
      ];

      final expenseSections = adapter.buildSections(
        legacyCategories: legacyCategories,
        type: CategoryType.expense,
        l10n: l10n,
      );
      final incomeSections = adapter.buildSections(
        legacyCategories: legacyCategories,
        type: CategoryType.income,
        l10n: l10n,
      );

      expect(expenseSections, hasLength(1));
      expect(
        expenseSections.single.group.key,
        ExpenseCategoryGroup.housing.l10nKey,
      );
      expect(
        expenseSections.single.items.single.definition.key,
        CategoryStableKey.expenseHousingRent,
      );
      expect(
        expenseSections.single.items.single.legacyCategory.id,
        'expense-rent',
      );

      expect(incomeSections, hasLength(1));
      expect(
        incomeSections.single.group.key,
        IncomeCategoryGroup.employment.l10nKey,
      );
      expect(
        incomeSections.single.items.single.definition.key,
        CategoryStableKey.incomeEmploymentSalary,
      );
      expect(
        incomeSections.single.items.single.legacyCategory.id,
        'income-salary',
      );
    });

    test('does not include transfer-like legacy rows in expense sections', () {
      final sections = adapter.buildSections(
        legacyCategories: [
          _category(
            id: 'transfer',
            type: CategoryType.expense,
            nameKey: 'categoryTransfer',
          ),
        ],
        type: CategoryType.expense,
        l10n: l10n,
      );

      expect(sections, isEmpty);
    });

    test('hides broad legacy rows without stableKey', () {
      final sections = adapter.buildSections(
        legacyCategories: [
          _category(
            id: 'broad-utilities',
            type: CategoryType.expense,
            nameKey: 'categoryUtilities',
          ),
        ],
        type: CategoryType.expense,
        l10n: l10n,
      );

      expect(sections, isEmpty);
    });

    test('includes inactive taxonomy row with stableKey', () {
      final sections = adapter.buildSections(
        legacyCategories: [
          _category(
            id: 'inactive-internet',
            type: CategoryType.expense,
            nameKey: 'categoryTaxonomyExpenseHousingInternetName',
            stableKey: 'expense.housing.internet',
            isActive: false,
          ),
        ],
        type: CategoryType.expense,
        l10n: l10n,
      );

      final item = sections.single.items.single;

      expect(item.legacyCategory.id, 'inactive-internet');
      expect(item.definition.key, CategoryStableKey.expenseHousingInternet);
    });

    test('picker item keeps the real legacy Category as selectable result', () {
      final legacyCategory = _category(
        id: 'legacy-groceries',
        type: CategoryType.expense,
        nameKey: 'categoryGroceries',
      );

      final sections = adapter.buildSections(
        legacyCategories: [legacyCategory],
        type: CategoryType.expense,
        l10n: l10n,
      );

      final item = sections.single.items.single;

      expect(identical(item.legacyCategory, legacyCategory), isTrue);
      expect(item.legacyCategory.id, 'legacy-groceries');
      expect(item.definition.key, CategoryStableKey.expenseFoodGroceries);
      expect(item.presentation.stableKey, 'expense.food.groceries');
    });

    test('unmapped taxonomy definitions are not selectable', () {
      final sections = adapter.buildSections(
        legacyCategories: [
          _category(
            id: 'legacy-rent',
            type: CategoryType.expense,
            nameKey: 'categoryRent',
          ),
        ],
        type: CategoryType.expense,
        l10n: l10n,
      );

      final stableKeys = sections
          .expand((section) => section.items)
          .map((item) => item.definition.key)
          .toSet();

      expect(stableKeys, contains(CategoryStableKey.expenseHousingRent));
      expect(
        stableKeys,
        isNot(contains(CategoryStableKey.expenseHousingInternet)),
      );
    });

    test(
      'audit lists mapped legacy, unmapped legacy, and unselectable taxonomy',
      () {
        final result = adapter.audit(
          legacyCategories: [
            _category(
              id: 'legacy-rent',
              type: CategoryType.expense,
              nameKey: 'categoryRent',
            ),
            _category(
              id: 'legacy-unknown',
              type: CategoryType.expense,
              nameKey: 'categoryUnknown',
            ),
            _category(
              id: 'legacy-salary',
              type: CategoryType.income,
              nameKey: 'categorySalary',
            ),
          ],
          type: CategoryType.expense,
        );

        expect(result.mappedLegacyCategoryNameKeys, contains('categoryRent'));
        expect(
          result.unmappedLegacyCategoryNameKeys,
          contains('categoryUnknown'),
        );
        expect(
          result.mappedLegacyCategoryNameKeys,
          isNot(contains('categorySalary')),
        );
        expect(
          result.unselectableTaxonomyStableKeys,
          contains('expense.housing.internet'),
        );
      },
    );
  });
}

Category _category({
  required String id,
  required CategoryType type,
  required String nameKey,
  String? stableKey,
  bool isActive = true,
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

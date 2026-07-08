import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/entities/legacy_category_bridge.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';

void main() {
  const bridge = LegacyCategoryBridge();

  group('LegacyCategoryBridge', () {
    test('prefers stableKey over nameKey', () {
      final category = _category(
        nameKey: 'categoryGroceries',
        stableKey: 'expense.housing.rent',
      );

      final definition = bridge.definitionFor(category);

      expect(definition?.key, CategoryStableKey.expenseHousingRent);
    });

    test('does not fallback when non-null stableKey is invalid', () {
      final category = _category(
        nameKey: 'categoryGroceries',
        stableKey: 'expense.unknown.invalid',
      );

      expect(bridge.definitionFor(category), isNull);
    });

    test('does not fallback when non-null stableKey type mismatches', () {
      final category = _category(
        type: CategoryType.expense,
        nameKey: 'categoryGroceries',
        stableKey: 'income.employment.salary',
      );

      expect(bridge.definitionFor(category), isNull);
    });

    test('approved fallback rows still work without stableKey', () {
      final category = _category(nameKey: 'categoryGroceries');

      final definition = bridge.definitionFor(category);

      expect(definition?.key, CategoryStableKey.expenseFoodGroceries);
    });

    test('broad rows do not map through fallback without stableKey', () {
      final category = _category(nameKey: 'categoryUtilities');

      expect(bridge.definitionFor(category), isNull);
    });
  });
}

Category _category({
  CategoryType type = CategoryType.expense,
  required String nameKey,
  String? stableKey,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: 'category-id',
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
    isActive: true,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey,
  );
}

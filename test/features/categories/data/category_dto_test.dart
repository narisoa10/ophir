import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/categories/data/dto/category_dto.dart';
import 'package:ophir/features/categories/data/mappers/category_mapper.dart';

void main() {
  group('CategoryDto', () {
    test('parses stable_key', () {
      final dto = CategoryDto.fromJson(
        _json(stableKey: 'expense.food.groceries'),
      );

      expect(dto.stableKey, 'expense.food.groceries');
    });

    test('works when stable_key is missing', () {
      final json = _json()..remove('stable_key');

      final dto = CategoryDto.fromJson(json);

      expect(dto.stableKey, isNull);
    });

    test('works when stable_key is null', () {
      final dto = CategoryDto.fromJson(_json(stableKey: null));

      expect(dto.stableKey, isNull);
    });

    test('mapper passes stableKey to Category', () {
      final dto = CategoryDto.fromJson(
        _json(stableKey: 'expense.food.groceries'),
      );

      final category = dto.toEntity();

      expect(category.stableKey, 'expense.food.groceries');
    });
  });
}

Map<String, dynamic> _json({String? stableKey}) {
  return {
    'id': 'category-id',
    'type': 'expense',
    'group_key': 'food',
    'name_key': 'categoryGroceries',
    'icon_key': 'groceries',
    'color_key': 'green',
    'sort_order': 100,
    'is_active': true,
    'created_at': '2026-01-01T00:00:00.000Z',
    'updated_at': '2026-01-01T00:00:00.000Z',
    'example_key': 'categoryExampleGroceries',
    'stable_key': stableKey,
  };
}

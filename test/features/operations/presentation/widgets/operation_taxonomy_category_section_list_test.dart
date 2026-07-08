import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/icons/app_icons.dart';
import 'package:ophir/core/theme_v1/app_category_colors.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/entities/category_taxonomy.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/presentation/models/category_definition_presentation.dart';
import 'package:ophir/features/categories/presentation/models/category_group_presentation.dart';
import 'package:ophir/features/categories/presentation/models/category_picker_taxonomy_item.dart';
import 'package:ophir/features/categories/presentation/models/category_picker_taxonomy_section.dart';
import 'package:ophir/features/operations/presentation/widgets/operation_taxonomy_category_section_list.dart';

void main() {
  group('OperationTaxonomyCategorySectionList', () {
    testWidgets('shows groups collapsed and keeps one expanded group', (
      tester,
    ) async {
      await tester.pumpWidget(
        _App(
          child: OperationTaxonomyCategorySectionList(
            sections: [
              _section(
                groupKey: 'housing',
                groupName: 'Housing',
                categoryId: 'rent',
                categoryName: 'Rent',
                stableKey: 'expense.housing.rent',
              ),
              _section(
                groupKey: 'food',
                groupName: 'Food',
                categoryId: 'groceries',
                categoryName: 'Groceries',
                stableKey: 'expense.food.groceries',
              ),
            ],
            onCategorySelected: (_) {},
          ),
        ),
      );

      expect(find.text('Housing'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Rent'), findsNothing);
      expect(find.text('Groceries'), findsNothing);

      await tester.tap(find.text('Housing'));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsNothing);
      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('returns the legacy category when item is tapped', (
      tester,
    ) async {
      Category? selectedCategory;

      await tester.pumpWidget(
        _App(
          child: OperationTaxonomyCategorySectionList(
            sections: [
              _section(
                groupKey: 'housing',
                groupName: 'Housing',
                categoryId: 'rent',
                categoryName: 'Rent',
                stableKey: 'expense.housing.rent',
              ),
            ],
            onCategorySelected: (category) {
              selectedCategory = category;
            },
          ),
        ),
      );

      await tester.tap(find.text('Housing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rent'));

      expect(selectedCategory?.id, 'rent');
    });

    testWidgets('collapses a group when the same group is tapped again', (
      tester,
    ) async {
      await tester.pumpWidget(
        _App(
          child: OperationTaxonomyCategorySectionList(
            sections: [
              _section(
                groupKey: 'housing',
                groupName: 'Housing',
                categoryId: 'rent',
                categoryName: 'Rent',
                stableKey: 'expense.housing.rent',
              ),
            ],
            onCategorySelected: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Housing'));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsOneWidget);

      await tester.tap(find.text('Housing'));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsNothing);
    });

    testWidgets('long labels stay inside a compact viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _App(
          child: OperationTaxonomyCategorySectionList(
            sections: [
              _section(
                groupKey: 'long-group',
                groupName:
                    'A very long category group label that should truncate',
                categoryId: 'long-category',
                categoryName:
                    'A very long category label that should truncate cleanly',
                stableKey: 'expense.housing.rent',
              ),
            ],
            onCategorySelected: (_) {},
          ),
        ),
      );

      await tester.tap(
        find.text('A very long category group label that should truncate'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'A very long category label that should truncate cleanly',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });
  });
}

final class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: child));
  }
}

CategoryPickerTaxonomySection _section({
  required String groupKey,
  required String groupName,
  required String categoryId,
  required String categoryName,
  required String stableKey,
}) {
  final definition = CategoryTaxonomy.definitionForStableKey(stableKey)!;

  return CategoryPickerTaxonomySection(
    group: CategoryGroupPresentation(
      key: groupKey,
      name: groupName,
      sortOrder: definition.sortOrder,
    ),
    items: [
      CategoryPickerTaxonomyItem(
        legacyCategory: _category(
          id: categoryId,
          nameKey: definition.nameL10nKey,
          stableKey: stableKey,
        ),
        definition: definition,
        presentation: CategoryDefinitionPresentation(
          stableKey: stableKey,
          name: categoryName,
          icon: AppIcons.categoryHousing,
          color: AppCategoryColors.fromKey(definition.colorKey),
          backgroundColor: AppCategoryColors.backgroundFromKey(
            definition.colorKey,
          ),
          type: definition.type,
          sortOrder: definition.sortOrder,
        ),
      ),
    ],
  );
}

Category _category({
  required String id,
  required String nameKey,
  required String stableKey,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: CategoryType.expense,
    uiGroup: CategoryUiGroup.dailyLife,
    analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
    nameKey: nameKey,
    iconKey: 'housing',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: false,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey,
  );
}

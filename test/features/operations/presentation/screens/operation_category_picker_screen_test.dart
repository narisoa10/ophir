import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/icons/app_icons.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/theme_v1/app_category_colors.dart';
import 'package:ophir/features/categories/controller/category_picker_taxonomy_providers.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/entities/category_taxonomy.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/presentation/models/category_definition_presentation.dart';
import 'package:ophir/features/categories/presentation/models/category_group_presentation.dart';
import 'package:ophir/features/categories/presentation/models/category_picker_taxonomy_item.dart';
import 'package:ophir/features/categories/presentation/models/category_picker_taxonomy_section.dart';
import 'package:ophir/features/operations/presentation/screens/operation_category_picker_screen.dart';

void main() {
  group('OperationCategoryPickerScreen', () {
    testWidgets('returns selected taxonomy item legacy category', (
      tester,
    ) async {
      Category? selectedCategory;
      final category = _category(
        id: 'rent',
        nameKey: 'categoryTaxonomyExpenseHousingRentName',
        stableKey: 'expense.housing.rent',
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              return TextButton(
                onPressed: () async {
                  selectedCategory = await context.push<Category>('/picker');
                },
                child: const Text('Open picker'),
              );
            },
          ),
          GoRoute(
            path: '/picker',
            builder: (context, state) {
              return const OperationCategoryPickerScreen(
                type: CategoryType.expense,
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseCategoryPickerTaxonomySectionsProvider.overrideWith((
              ref,
              l10n,
            ) async {
              return Success([
                _section(
                  groupKey: 'housing',
                  groupName: 'Housing',
                  category: category,
                  categoryName: 'Rent',
                  stableKey: 'expense.housing.rent',
                ),
              ]);
            }),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Housing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rent'));
      await tester.pumpAndSettle();

      expect(selectedCategory?.id, 'rent');
      expect(selectedCategory?.stableKey, 'expense.housing.rent');
    });

    testWidgets('shows localized empty state for empty taxonomy sections', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              return const OperationCategoryPickerScreen(
                type: CategoryType.expense,
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseCategoryPickerTaxonomySectionsProvider.overrideWith((
              ref,
              l10n,
            ) async {
              return const Success([]);
            }),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No categories available.'), findsOneWidget);
      expect(find.text('Something went wrong.'), findsNothing);
    });
  });
}

CategoryPickerTaxonomySection _section({
  required String groupKey,
  required String groupName,
  required Category category,
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
        legacyCategory: category,
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

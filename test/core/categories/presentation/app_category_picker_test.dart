import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/categories/presentation/app_category_picker.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('showAppCategoryPicker', () {
    testWidgets('shows collapsed groups and returns selected category', (
      tester,
    ) async {
      AppCategory? selectedCategory;

      await tester.pumpWidget(
        _pickerApp(
          categories: AppCategories.incomeCategories,
          onSelected: (category) {
            selectedCategory = category;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-picker')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('app-category-picker-group-employmentIncome'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'app-category-picker-category-incomeEmploymentSalary',
          ),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('app-category-picker-group-employmentIncome'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>(
            'app-category-picker-category-incomeEmploymentSalary',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'app-category-picker-category-incomeEmploymentSalary',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(selectedCategory?.id, AppCategoryId.incomeEmploymentSalary);
    });

    testWidgets('supports multiple expanded groups on one screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _pickerApp(categories: AppCategories.expenseCategories),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-picker')));
      await tester.pumpAndSettle();

      final pickerScrollable = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );

      final housingGroup = find.byKey(
        const ValueKey<String>('app-category-picker-group-housing'),
      );
      final housingCategory = find.byKey(
        const ValueKey<String>(
          'app-category-picker-category-expenseHousingRent',
        ),
      );
      final foodGroup = find.byKey(
        const ValueKey<String>('app-category-picker-group-food'),
      );
      final foodCategory = find.byKey(
        const ValueKey<String>(
          'app-category-picker-category-expenseFoodGroceries',
        ),
      );

      await tester.scrollUntilVisible(
        housingGroup,
        120,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(housingGroup);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        housingCategory,
        120,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      expect(housingCategory, findsOneWidget);

      await tester.scrollUntilVisible(
        foodGroup,
        120,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(foodGroup);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        foodCategory,
        120,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      expect(foodCategory, findsOneWidget);

      await tester.scrollUntilVisible(
        housingGroup,
        -120,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        housingCategory,
        120,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      expect(housingCategory, findsOneWidget);

      await tester.scrollUntilVisible(
        foodGroup,
        120,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        foodCategory,
        120,
        scrollable: pickerScrollable,
      );
      await tester.pumpAndSettle();
      expect(foodCategory, findsOneWidget);
    });

    testWidgets('shows empty state for empty category scope', (tester) async {
      await tester.pumpWidget(_pickerApp(categories: const []));

      await tester.tap(find.byKey(const ValueKey<String>('open-picker')));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.operationCategoryPickerEmpty), findsOneWidget);
    });
  });
}

Widget _pickerApp({
  required Iterable<AppCategory> categories,
  ValueChanged<AppCategory>? onSelected,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            key: const ValueKey<String>('open-picker'),
            onPressed: () async {
              final selected = await showAppCategoryPicker(
                context: context,
                categories: categories,
              );

              if (selected != null) {
                onSelected?.call(selected);
              }
            },
            child: Text(_l10n.operationChooseCategory),
          );
        },
      ),
    ),
  );
}

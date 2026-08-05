import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/icons/app_category_icons.dart';
import 'package:ophir/core/icons/app_icons.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/widgets/app_financial_list_tile.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_section.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('MandatoryExpenseSection', () {
    testWidgets('collapsed state shows group summary without child rows', (
      tester,
    ) async {
      var toggled = false;
      final categories = _categories(AppCategoryGroup.housing);
      final groupTitle = _groupName(AppCategoryGroup.housing);

      await tester.pumpWidget(
        _sectionApp(
          categories: categories,
          isExpanded: false,
          onToggle: () {
            toggled = true;
          },
        ),
      );

      expect(find.text(groupTitle), findsOneWidget);
      expect(find.text('42.00 CAD'), findsOneWidget);
      expect(
        find.byIcon(AppCategoryIcons.fromKey(AppCategoryIcons.housing)),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.actionChevronDown), findsOneWidget);
      expect(find.byIcon(AppIcons.actionChevronUp), findsNothing);
      expect(find.text(categories.first.name(_l10n)), findsNothing);

      await tester.tap(_headerTile(groupTitle));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    });

    testWidgets('expanded state shows group summary and child expense rows', (
      tester,
    ) async {
      AppCategory? tappedCategory;
      final categories = _categories(AppCategoryGroup.housing).take(2).toList();
      final groupTitle = _groupName(AppCategoryGroup.housing);

      await tester.pumpWidget(
        _sectionApp(
          categories: categories,
          isExpanded: true,
          onCategoryTap: (category) {
            tappedCategory = category;
          },
        ),
      );

      expect(find.text(groupTitle), findsOneWidget);
      expect(find.text('42.00 CAD'), findsOneWidget);
      expect(find.byIcon(AppIcons.actionChevronUp), findsOneWidget);
      expect(find.byType(AppFinancialListTile), findsNWidgets(3));
      expect(
        find.text(_l10n.budgetExpenseNotFilled),
        findsNWidgets(categories.length),
      );

      for (final category in categories) {
        expect(find.text(category.name(_l10n)), findsOneWidget);
      }

      await tester.tap(_childTile(categories.last));
      await tester.pumpAndSettle();

      expect(tappedCategory, categories.last);
    });
  });
}

Finder _childTile(AppCategory category) {
  return find
      .ancestor(
        of: find.text(category.name(_l10n)),
        matching: find.byType(AppFinancialListTile),
      )
      .first;
}

Finder _headerTile(String title) {
  return find.widgetWithText(AppFinancialListTile, title).first;
}

Widget _sectionApp({
  required List<AppCategory> categories,
  required bool isExpanded,
  VoidCallback? onToggle,
  ValueChanged<AppCategory>? onCategoryTap,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MandatoryExpenseSection(
        title: _groupName(AppCategoryGroup.housing),
        iconKey: AppCategoryIcons.housing,
        categories: categories,
        selectedCount: 1,
        formattedAmount: '42.00 CAD',
        isExpanded: isExpanded,
        onToggle: onToggle ?? () {},
        currencyCode: 'CAD',
        obligationFor: (_) => null,
        onCategoryTap: onCategoryTap ?? (_) {},
      ),
    ),
  );
}

List<AppCategory> _categories(AppCategoryGroup group) {
  return AppCategories.mandatoryExpenseCategories(group);
}

String _groupName(AppCategoryGroup group) {
  return AppCategories.mandatoryExpenseCategories(group).first.groupName(_l10n);
}

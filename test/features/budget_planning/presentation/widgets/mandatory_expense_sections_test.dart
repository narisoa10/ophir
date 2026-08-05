import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/categories/app_categories.dart';
import 'package:ophir/core/icons/app_category_icons.dart';
import 'package:ophir/core/icons/app_icons.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/widgets/app_financial_list_tile.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_education.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_family.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_finance.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_food.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_giving.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_government.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_health.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_housing.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_personal_care.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_pets.dart';
import 'package:ophir/features/budget_planning/presentation/widgets/mandatory_expense_sections/mandatory_expense_transportation.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('mandatory expense section wrappers', () {
    for (final config in _sectionConfigs()) {
      testWidgets('${config.name} shows group summary when collapsed', (
        tester,
      ) async {
        var toggled = false;

        await tester.pumpWidget(
          _wrapperApp(
            config,
            isExpanded: false,
            onToggle: () {
              toggled = true;
            },
          ),
        );

        expect(find.text(config.title), findsOneWidget);
        expect(find.text('42.00 CAD'), findsOneWidget);
        expect(
          find.byIcon(AppCategoryIcons.fromKey(config.iconKey)),
          findsOneWidget,
        );
        expect(find.byIcon(AppIcons.actionChevronDown), findsOneWidget);
        expect(find.byIcon(AppIcons.actionChevronUp), findsNothing);

        for (final category in config.categories) {
          expect(find.text(category.name(_l10n)), findsNothing);
        }

        await tester.tap(_headerTile(config.title));
        await tester.pumpAndSettle();

        expect(toggled, isTrue);
      });

      testWidgets('${config.name} shows child rows when expanded', (
        tester,
      ) async {
        AppCategory? tappedCategory;

        await tester.pumpWidget(
          _wrapperApp(
            config,
            isExpanded: true,
            onCategoryTap: (category) {
              tappedCategory = category;
            },
          ),
        );

        expect(find.text(config.title), findsOneWidget);
        expect(find.text('42.00 CAD'), findsOneWidget);
        expect(find.byIcon(AppIcons.actionChevronUp), findsOneWidget);
        expect(
          find.byType(AppFinancialListTile),
          findsNWidgets(config.categories.length + 1),
        );

        for (final category in config.categories) {
          expect(find.text(category.name(_l10n)), findsOneWidget);
        }

        if (config.group == AppCategoryGroup.giving) {
          final switchFinder = find.byType(Switch);
          await tester.ensureVisible(switchFinder);
          await tester.pumpAndSettle();
          await tester.tap(switchFinder);
        } else {
          final childTile = _childTile(config.categories.first);
          await tester.ensureVisible(childTile);
          await tester.pumpAndSettle();
          await tester.tap(childTile);
        }
        await tester.pumpAndSettle();

        expect(tappedCategory, config.categories.first);
      });
    }
  });
}

Widget _wrapperApp(
  _SectionConfig config, {
  required bool isExpanded,
  VoidCallback? onToggle,
  ValueChanged<AppCategory>? onCategoryTap,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: config.build(
          categories: config.categories,
          isExpanded: isExpanded,
          onToggle: onToggle ?? () {},
          onCategoryTap: onCategoryTap ?? (_) {},
        ),
      ),
    ),
  );
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

List<_SectionConfig> _sectionConfigs() {
  return [
    _SectionConfig(
      name: 'housing',
      group: AppCategoryGroup.housing,
      iconKey: AppCategoryIcons.housing,
      build: _housing,
    ),
    _SectionConfig(
      name: 'transportation',
      group: AppCategoryGroup.transportation,
      iconKey: AppCategoryIcons.publicTransit,
      build: _transportation,
    ),
    _SectionConfig(
      name: 'food',
      group: AppCategoryGroup.food,
      iconKey: AppCategoryIcons.groceries,
      build: _food,
    ),
    _SectionConfig(
      name: 'health',
      group: AppCategoryGroup.health,
      iconKey: AppCategoryIcons.health,
      build: _health,
    ),
    _SectionConfig(
      name: 'family',
      group: AppCategoryGroup.family,
      iconKey: AppCategoryIcons.childcare,
      build: _family,
    ),
    _SectionConfig(
      name: 'personal care',
      group: AppCategoryGroup.personalCare,
      iconKey: AppCategoryIcons.personalHygiene,
      build: _personalCare,
    ),
    _SectionConfig(
      name: 'education',
      group: AppCategoryGroup.education,
      iconKey: AppCategoryIcons.education,
      build: _education,
    ),
    _SectionConfig(
      name: 'finance',
      group: AppCategoryGroup.finance,
      iconKey: AppCategoryIcons.bankFees,
      build: _finance,
    ),
    _SectionConfig(
      name: 'government',
      group: AppCategoryGroup.governmentExpense,
      iconKey: AppCategoryIcons.governmentServices,
      build: _government,
    ),
    _SectionConfig(
      name: 'pets',
      group: AppCategoryGroup.pets,
      iconKey: AppCategoryIcons.petFood,
      build: _pets,
    ),
    _SectionConfig(
      name: 'giving',
      group: AppCategoryGroup.giving,
      iconKey: AppCategoryIcons.donations,
      build: _giving,
    ),
  ];
}

Widget _housing({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseHousing(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _transportation({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseTransportation(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _food({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseFood(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _health({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseHealth(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _family({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseFamily(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _personalCare({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpensePersonalCare(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _education({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseEducation(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _finance({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseFinance(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _government({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseGovernment(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _pets({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpensePets(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

Widget _giving({
  required List<AppCategory> categories,
  required bool isExpanded,
  required VoidCallback onToggle,
  required ValueChanged<AppCategory> onCategoryTap,
}) {
  return MandatoryExpenseGiving(
    categories: categories,
    selectedCount: 1,
    formattedAmount: '42.00 CAD',
    isExpanded: isExpanded,
    onToggle: onToggle,
    currencyCode: 'CAD',
    obligationFor: (_) => null,
    onCategoryTap: onCategoryTap,
  );
}

typedef _WrapperBuilder =
    Widget Function({
      required List<AppCategory> categories,
      required bool isExpanded,
      required VoidCallback onToggle,
      required ValueChanged<AppCategory> onCategoryTap,
    });

final class _SectionConfig {
  _SectionConfig({
    required this.name,
    required this.group,
    required this.iconKey,
    required this.build,
  }) : categories = AppCategories.mandatoryExpenseCategories(group),
       title = AppCategories.mandatoryExpenseCategories(
         group,
       ).first.groupName(_l10n);

  final String name;
  final AppCategoryGroup group;
  final String iconKey;
  final _WrapperBuilder build;
  final List<AppCategory> categories;
  final String title;
}

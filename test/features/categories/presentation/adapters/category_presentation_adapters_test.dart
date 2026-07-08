import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/localization/generated/app_localizations_en.dart';
import 'package:ophir/core/localization/generated/app_localizations_fr.dart';
import 'package:ophir/core/localization/generated/app_localizations_ru.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/entities/category_taxonomy.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/categories/presentation/adapters/category_definition_adapter.dart';
import 'package:ophir/features/categories/presentation/adapters/category_presentation_adapters.dart';

void main() {
  group('CategoryDefinitionAdapter', () {
    test('displays English taxonomy category-only labels through l10n', () {
      final definition = CategoryTaxonomy.definitionForStableKey(
        'expense.housing.rent',
      )!;

      final presentation = const CategoryDefinitionAdapter().toPresentation(
        definition,
        AppLocalizationsEn(),
      );

      expect(presentation.name, 'Rent');
      expect(presentation.name, isNot('Housing Rent'));
    });

    test('displays Russian taxonomy labels through l10n', () {
      final definition = CategoryTaxonomy.definitionForStableKey(
        'expense.housing.rent',
      )!;

      final presentation = const CategoryDefinitionAdapter().toPresentation(
        definition,
        AppLocalizationsRu(),
      );

      expect(presentation.name, '\u0410\u0440\u0435\u043d\u0434\u0430');
      expect(presentation.name, isNot('Housing Rent'));
    });

    test('displays French taxonomy labels through l10n', () {
      final rent = CategoryTaxonomy.definitionForStableKey(
        'expense.housing.rent',
      )!;
      final propertyTax = CategoryTaxonomy.definitionForStableKey(
        'expense.housing.property_tax',
      )!;
      const adapter = CategoryDefinitionAdapter();

      expect(adapter.toPresentation(rent, AppLocalizationsFr()).name, 'Loyer');
      expect(
        adapter.toPresentation(propertyTax, AppLocalizationsFr()).name,
        'Taxe fonci\u00e8re',
      );
    });
  });

  group('CategoryAdapter', () {
    test('displays stableKey taxonomy label through l10n', () {
      final presentation = const CategoryAdapter().toPresentation(
        _category(
          nameKey: 'categoryTaxonomyExpenseHousingInternetName',
          stableKey: 'expense.housing.internet',
          isActive: false,
        ),
        AppLocalizationsEn(),
      );

      expect(presentation.name, 'Internet');
      expect(presentation.name, isNot('Housing Internet'));
      expect(
        presentation.name,
        isNot('categoryTaxonomyExpenseHousingInternetName'),
      );
      expect(presentation.uiGroupName, 'Housing');
    });

    test('keeps legacy label behavior when stableKey is null', () {
      final presentation = const CategoryAdapter().toPresentation(
        _category(nameKey: 'categoryRent'),
        AppLocalizationsEn(),
      );

      expect(presentation.name, 'Rent');
    });

    test('displays Russian taxonomy category and group through l10n', () {
      final presentation = const CategoryAdapter().toPresentation(
        _category(
          nameKey: 'categoryTaxonomyExpenseHousingRentName',
          stableKey: 'expense.housing.rent',
          isActive: false,
        ),
        AppLocalizationsRu(),
      );

      expect(presentation.name, '\u0410\u0440\u0435\u043d\u0434\u0430');
      expect(presentation.name, isNot('Housing Rent'));
      expect(presentation.uiGroupName, '\u0416\u0438\u043b\u044c\u0451');
    });
  });
}

Category _category({
  required String nameKey,
  String? stableKey,
  bool isActive = true,
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: 'category',
    type: CategoryType.expense,
    uiGroup: CategoryUiGroup.dailyLife,
    analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
    nameKey: nameKey,
    iconKey: 'housing',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey,
  );
}

import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/category_definition.dart';
import '../../domain/entities/category_taxonomy.dart';
import '../../domain/entities/legacy_category_bridge.dart';
import '../../domain/enums/category_stable_key.dart';
import '../../domain/enums/category_type.dart';
import '../../domain/enums/expense_category_group.dart';
import '../../domain/enums/income_category_group.dart';
import '../models/category_picker_taxonomy_audit_result.dart';
import '../models/category_picker_taxonomy_item.dart';
import '../models/category_picker_taxonomy_section.dart';
import 'category_definition_adapter.dart';
import 'expense_category_group_adapter.dart';
import 'income_category_group_adapter.dart';

final class CategoryPickerTaxonomyAdapter {
  const CategoryPickerTaxonomyAdapter({
    LegacyCategoryBridge bridge = const LegacyCategoryBridge(),
    CategoryDefinitionAdapter definitionAdapter =
        const CategoryDefinitionAdapter(),
    ExpenseCategoryGroupAdapter expenseGroupAdapter =
        const ExpenseCategoryGroupAdapter(),
    IncomeCategoryGroupAdapter incomeGroupAdapter =
        const IncomeCategoryGroupAdapter(),
  }) : _bridge = bridge,
       _definitionAdapter = definitionAdapter,
       _expenseGroupAdapter = expenseGroupAdapter,
       _incomeGroupAdapter = incomeGroupAdapter;

  final LegacyCategoryBridge _bridge;
  final CategoryDefinitionAdapter _definitionAdapter;
  final ExpenseCategoryGroupAdapter _expenseGroupAdapter;
  final IncomeCategoryGroupAdapter _incomeGroupAdapter;

  List<CategoryPickerTaxonomySection> buildSections({
    required List<Category> legacyCategories,
    required CategoryType type,
    required AppLocalizations l10n,
  }) {
    final legacyByStableKey = _legacyByStableKey(legacyCategories, type);

    return switch (type) {
      CategoryType.expense => _buildExpenseSections(legacyByStableKey, l10n),
      CategoryType.income => _buildIncomeSections(legacyByStableKey, l10n),
    };
  }

  CategoryPickerTaxonomyAuditResult audit({
    required List<Category> legacyCategories,
    required CategoryType type,
  }) {
    final mapped = <String>[];
    final unmapped = <String>[];
    final mappedStableKeys = <CategoryStableKey>{};

    for (final category in legacyCategories.where(
      (item) => item.type == type,
    )) {
      final definition = _bridge.definitionFor(category);

      if (definition == null) {
        unmapped.add(category.nameKey);
      } else {
        mapped.add(category.nameKey);
        mappedStableKeys.add(definition.key);
      }
    }

    final unselectable = CategoryTaxonomy.byType(type)
        .where((definition) => !mappedStableKeys.contains(definition.key))
        .map((definition) => definition.stableKey)
        .toList(growable: false);

    return CategoryPickerTaxonomyAuditResult(
      mappedLegacyCategoryNameKeys: List.unmodifiable(mapped),
      unmappedLegacyCategoryNameKeys: List.unmodifiable(unmapped),
      unselectableTaxonomyStableKeys: List.unmodifiable(unselectable),
    );
  }

  Map<CategoryStableKey, Category> _legacyByStableKey(
    List<Category> legacyCategories,
    CategoryType type,
  ) {
    final sorted =
        legacyCategories
            .where((category) => category.type == type)
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final mapped = <CategoryStableKey, Category>{};

    for (final category in sorted) {
      final definition = _bridge.definitionFor(category);

      if (definition != null) {
        mapped.putIfAbsent(definition.key, () => category);
      }
    }

    return mapped;
  }

  List<CategoryPickerTaxonomySection> _buildExpenseSections(
    Map<CategoryStableKey, Category> legacyByStableKey,
    AppLocalizations l10n,
  ) {
    return [
      for (final group in ExpenseCategoryGroup.values)
        _expenseSection(group, legacyByStableKey, l10n),
    ].whereType<CategoryPickerTaxonomySection>().toList(growable: false);
  }

  List<CategoryPickerTaxonomySection> _buildIncomeSections(
    Map<CategoryStableKey, Category> legacyByStableKey,
    AppLocalizations l10n,
  ) {
    return [
      for (final group in IncomeCategoryGroup.values)
        _incomeSection(group, legacyByStableKey, l10n),
    ].whereType<CategoryPickerTaxonomySection>().toList(growable: false);
  }

  CategoryPickerTaxonomySection? _expenseSection(
    ExpenseCategoryGroup group,
    Map<CategoryStableKey, Category> legacyByStableKey,
    AppLocalizations l10n,
  ) {
    final items = _items(
      CategoryTaxonomy.byType(
        CategoryType.expense,
      ).where((definition) => definition.expenseGroup == group),
      legacyByStableKey,
      l10n,
    );

    if (items.isEmpty) {
      return null;
    }

    return CategoryPickerTaxonomySection(
      group: _expenseGroupAdapter.toPresentation(group, l10n),
      items: items,
    );
  }

  CategoryPickerTaxonomySection? _incomeSection(
    IncomeCategoryGroup group,
    Map<CategoryStableKey, Category> legacyByStableKey,
    AppLocalizations l10n,
  ) {
    final items = _items(
      CategoryTaxonomy.byType(
        CategoryType.income,
      ).where((definition) => definition.incomeGroup == group),
      legacyByStableKey,
      l10n,
    );

    if (items.isEmpty) {
      return null;
    }

    return CategoryPickerTaxonomySection(
      group: _incomeGroupAdapter.toPresentation(group, l10n),
      items: items,
    );
  }

  List<CategoryPickerTaxonomyItem> _items(
    Iterable<CategoryDefinition> definitions,
    Map<CategoryStableKey, Category> legacyByStableKey,
    AppLocalizations l10n,
  ) {
    return definitions
        .where((definition) => legacyByStableKey.containsKey(definition.key))
        .map(
          (definition) => CategoryPickerTaxonomyItem(
            legacyCategory: legacyByStableKey[definition.key]!,
            definition: definition,
            presentation: _definitionAdapter.toPresentation(definition, l10n),
          ),
        )
        .toList(growable: false);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../domain/entities/category.dart';
import '../domain/enums/category_type.dart';
import '../presentation/adapters/category_picker_taxonomy_adapter.dart';
import '../presentation/models/category_picker_taxonomy_section.dart';
import 'category_providers.dart';

final expenseCategoryPickerTaxonomySectionsProvider =
    FutureProvider.family<
      Result<List<CategoryPickerTaxonomySection>>,
      AppLocalizations
    >((ref, l10n) async {
      final result = await ref.watch(expenseTaxonomyCategoriesProvider.future);
      return _toTaxonomySections(result, CategoryType.expense, l10n);
    });

final incomeCategoryPickerTaxonomySectionsProvider =
    FutureProvider.family<
      Result<List<CategoryPickerTaxonomySection>>,
      AppLocalizations
    >((ref, l10n) async {
      final result = await ref.watch(incomeTaxonomyCategoriesProvider.future);
      return _toTaxonomySections(result, CategoryType.income, l10n);
    });

Result<List<CategoryPickerTaxonomySection>> _toTaxonomySections(
  Result<List<Category>> result,
  CategoryType type,
  AppLocalizations l10n,
) {
  return switch (result) {
    Success<List<Category>>(:final value) => Success(
      const CategoryPickerTaxonomyAdapter().buildSections(
        legacyCategories: value,
        type: type,
        l10n: l10n,
      ),
    ),
    Failure<List<Category>>(:final failure) => Failure(failure),
  };
}

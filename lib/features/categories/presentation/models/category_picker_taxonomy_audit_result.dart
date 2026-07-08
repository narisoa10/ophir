final class CategoryPickerTaxonomyAuditResult {
  const CategoryPickerTaxonomyAuditResult({
    required this.mappedLegacyCategoryNameKeys,
    required this.unmappedLegacyCategoryNameKeys,
    required this.unselectableTaxonomyStableKeys,
  });

  final List<String> mappedLegacyCategoryNameKeys;
  final List<String> unmappedLegacyCategoryNameKeys;
  final List<String> unselectableTaxonomyStableKeys;
}

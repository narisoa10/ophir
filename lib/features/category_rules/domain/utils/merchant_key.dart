/// Normalizes merchant/note text for category rule matching.
/// Keep in sync with `public.normalize_merchant_key` in Supabase.
String normalizeMerchantKey(String? text) {
  final trimmed = (text ?? '').trim().toLowerCase();
  if (trimmed.isEmpty) {
    return '';
  }

  final withoutStoreNumber = trimmed.replaceAll(RegExp(r'\s+#\d+.*$'), '');
  return withoutStoreNumber.trim();
}

String formatMoney(
  double amount,
  String currencyCode, {
  required bool showPositiveSign,
}) {
  final sign = amount > 0 && showPositiveSign ? '+' : '';
  return '$sign${amount.toStringAsFixed(2)} $currencyCode';
}

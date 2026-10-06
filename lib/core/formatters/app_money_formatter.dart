import 'package:intl/intl.dart';

String formatAmount(double amount, {required String locale}) {
  return NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: 2,
  ).format(amount);
}

String formatMoney(
  double amount,
  String currencyCode, {
  required String locale,
  bool showPositiveSign = false,
}) {
  final sign = amount > 0 && showPositiveSign ? '+' : '';
  return '$sign${formatAmount(amount, locale: locale)} $currencyCode';
}

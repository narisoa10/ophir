import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/formatters/app_money_formatter.dart';

const _narrowNoBreakSpace = '\u202F';
const _noBreakSpace = '\u00A0';

void main() {
  group('formatMoney', () {
    final cases = {
      'en': {
        0.0: '0.00 CAD',
        12.5: '12.50 CAD',
        1234.56: '1,234.56 CAD',
        1234567.89: '1,234,567.89 CAD',
        -1234.56: '-1,234.56 CAD',
      },
      'fr': {
        0.0: '0,00 CAD',
        12.5: '12,50 CAD',
        1234.56: '1${_narrowNoBreakSpace}234,56 CAD',
        1234567.89:
            '1${_narrowNoBreakSpace}234${_narrowNoBreakSpace}567,89 CAD',
        -1234.56: '-1${_narrowNoBreakSpace}234,56 CAD',
      },
      'ru': {
        0.0: '0,00 CAD',
        12.5: '12,50 CAD',
        1234.56: '1${_noBreakSpace}234,56 CAD',
        1234567.89: '1${_noBreakSpace}234${_noBreakSpace}567,89 CAD',
        -1234.56: '-1${_noBreakSpace}234,56 CAD',
      },
    };

    cases.forEach((locale, expectations) {
      expectations.forEach((amount, expected) {
        test('$locale formats $amount', () {
          expect(formatMoney(amount, 'CAD', locale: locale), expected);
        });
      });
    });

    test('keeps the given currency code without converting the amount', () {
      expect(formatMoney(12.5, 'USD', locale: 'fr'), '12,50 USD');
    });

    test('adds a plus sign only when requested for positive amounts', () {
      expect(
        formatMoney(12.5, 'CAD', locale: 'en', showPositiveSign: true),
        '+12.50 CAD',
      );
      expect(
        formatMoney(-12.5, 'CAD', locale: 'en', showPositiveSign: true),
        '-12.50 CAD',
      );
      expect(
        formatMoney(0, 'CAD', locale: 'en', showPositiveSign: true),
        '0.00 CAD',
      );
    });
  });

  test('formatAmount formats the number without a currency', () {
    expect(formatAmount(1234.5, locale: 'ru'), '1${_noBreakSpace}234,50');
  });
}

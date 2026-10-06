import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/currency/product_currency.dart';

const _productCurrencyFile = 'lib/core/currency/product_currency.dart';

final _sqlDefinition = RegExp(
  r"function public\.product_currency_code\(\)[\s\S]*?select '([A-Z]{3})'::char\(3\)",
);

final _currencyLiteral = RegExp(r'''['"](CAD|USD|EUR|GBP)['"]''');

void main() {
  test('the product currency is CAD', () {
    expect(productCurrencyCode, 'CAD');
  });

  test('public.product_currency_code() returns the Dart product currency', () {
    final migrations =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    String? latestSqlCode;
    for (final migration in migrations) {
      final match = _sqlDefinition.firstMatch(migration.readAsStringSync());
      if (match != null) {
        latestSqlCode = match.group(1);
      }
    }

    expect(latestSqlCode, productCurrencyCode);
  });

  test('no currency code is spelled out anywhere else in lib', () {
    final offenders = <String>[
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') &&
            !file.path.contains('generated') &&
            file.path.replaceAll(r'\', '/') != _productCurrencyFile &&
            _currencyLiteral.hasMatch(file.readAsStringSync()))
          file.path,
    ];

    expect(offenders, isEmpty);
  });
}

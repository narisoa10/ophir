import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/category_rules/domain/utils/merchant_key.dart';

void main() {
  group('normalizeMerchantKey', () {
    test('lowercases and trims merchant text', () {
      expect(normalizeMerchantKey('  Costco  '), 'costco');
    });

    test('removes store number suffix', () {
      expect(normalizeMerchantKey('Costco #123 Montreal'), 'costco');
    });

    test('returns empty for blank input', () {
      expect(normalizeMerchantKey(null), '');
      expect(normalizeMerchantKey('   '), '');
    });
  });
}

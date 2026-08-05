import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production code does not query Supabase categories table', () {
    final forbiddenPatterns = [
      "from('categories')",
      'public.categories',
      'stable_key',
      'CategoryRepository',
    ];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final offenders = <String>[];

    for (final file in dartFiles) {
      final content = file.readAsStringSync();

      for (final pattern in forbiddenPatterns) {
        if (content.contains(pattern)) {
          offenders.add('${file.path}: $pattern');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}

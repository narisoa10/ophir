import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _arbDirectory = 'lib/core/localization/l10n';
const _templateLocale = 'en';
const _locales = ['en', 'fr', 'ru'];

// Matches `{name}` and `{name, plural|select|...`, but not plural/select
// branch bodies such as `one{...}` or `=1{...}`.
final _placeholderPattern = RegExp(r'(?<![\w=])\{(\w+)\s*[,}]');

Map<String, dynamic> _readArb(String locale) {
  final file = File('$_arbDirectory/app_$locale.arb');
  final content = file.readAsStringSync().replaceFirst('\uFEFF', '');
  return jsonDecode(content) as Map<String, dynamic>;
}

Set<String> _messageKeys(Map<String, dynamic> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}

Set<String> _placeholdersIn(String message) {
  return _placeholderPattern
      .allMatches(message)
      .map((match) => match.group(1)!)
      .toSet();
}

void main() {
  final arbs = {for (final locale in _locales) locale: _readArb(locale)};
  final template = arbs[_templateLocale]!;
  final templateKeys = _messageKeys(template);

  for (final locale in _locales) {
    test('app_$locale.arb has the same keys as the template', () {
      final keys = _messageKeys(arbs[locale]!);

      expect(
        templateKeys.difference(keys),
        isEmpty,
        reason: 'Missing in app_$locale.arb',
      );
      expect(
        keys.difference(templateKeys),
        isEmpty,
        reason: 'Not in app_$_templateLocale.arb',
      );
    });

    test('app_$locale.arb has no metadata without a message', () {
      final arb = arbs[locale]!;
      final orphanMetadata = arb.keys.where(
        (key) =>
            key.startsWith('@') &&
            !key.startsWith('@@') &&
            !arb.containsKey(key.substring(1)),
      );

      expect(orphanMetadata, isEmpty);
    });

    test('app_$locale.arb uses the template placeholders', () {
      final arb = arbs[locale]!;
      final mismatches = <String>[
        for (final key in templateKeys)
          if (arb[key] is String &&
              !_sameSet(
                _placeholdersIn(arb[key] as String),
                _placeholdersIn(template[key] as String),
              ))
            key,
      ];

      expect(mismatches, isEmpty);
    });
  }

  test('template metadata declares exactly the placeholders it uses', () {
    final mismatches = <String>[
      for (final key in templateKeys)
        if (template['@$key'] case {'placeholders': final Map placeholders})
          if (!_sameSet(
            placeholders.keys.cast<String>().toSet(),
            _placeholdersIn(template[key] as String),
          ))
            key,
    ];

    expect(mismatches, isEmpty);
  });
}

bool _sameSet(Set<String> a, Set<String> b) {
  return a.length == b.length && a.containsAll(b);
}

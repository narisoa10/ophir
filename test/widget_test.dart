import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('Smoke test renders a Flutter widget', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Text(_l10n.appTitle))),
    );

    expect(find.text(_l10n.appTitle), findsOneWidget);
  });
}

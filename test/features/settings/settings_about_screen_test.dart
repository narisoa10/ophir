import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/app/app_version_provider.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/settings/presentation/screens/settings_about_screen.dart';

void main() {
  const expectedVersionText = {
    'en': 'Version 2.3.4',
    'fr': 'Version 2.3.4',
    'ru': 'Версия 2.3.4',
  };

  for (final MapEntry(key: languageCode, value: versionText)
      in expectedVersionText.entries) {
    testWidgets('shows the runtime app version in $languageCode', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appVersionProvider.overrideWithValue('2.3.4')],
          child: MaterialApp(
            locale: Locale(languageCode),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsAboutScreen(),
          ),
        ),
      );

      expect(find.text(versionText), findsOneWidget);
    });
  }
}

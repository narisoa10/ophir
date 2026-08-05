import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/settings/controller/settings_providers.dart';
import 'package:ophir/features/settings/data/repositories/shared_preferences_settings_repository.dart';
import 'package:ophir/features/settings/domain/entities/app_theme_preference.dart';
import 'package:ophir/features/settings/domain/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesSettingsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns system when no theme preference is saved', () async {
      final repository = SharedPreferencesSettingsRepository();

      final preference = await repository.getThemePreference();

      expect(preference, AppThemePreference.system);
    });

    test('returns system for unknown saved theme preference', () async {
      SharedPreferences.setMockInitialValues({
        'settings.theme_preference': 'unexpected',
      });
      final repository = SharedPreferencesSettingsRepository();

      final preference = await repository.getThemePreference();

      expect(preference, AppThemePreference.system);
    });

    test('persists selected theme preference', () async {
      final repository = SharedPreferencesSettingsRepository();

      await repository.setThemePreference(AppThemePreference.dark);

      expect(await repository.getThemePreference(), AppThemePreference.dark);
    });
  });

  group('SettingsController', () {
    test('loads and updates theme preference', () async {
      final repository = _FakeSettingsRepository(AppThemePreference.system);
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(settingsControllerProvider.future),
        AppThemePreference.system,
      );

      await container
          .read(settingsControllerProvider.notifier)
          .setThemePreference(AppThemePreference.light);

      expect(repository.savedPreference, AppThemePreference.light);
      expect(
        container.read(settingsControllerProvider).value,
        AppThemePreference.light,
      );
    });
  });
}

final class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.savedPreference);

  AppThemePreference savedPreference;

  @override
  Future<AppThemePreference> getThemePreference() async {
    return savedPreference;
  }

  @override
  Future<void> setThemePreference(AppThemePreference preference) async {
    savedPreference = preference;
  }
}

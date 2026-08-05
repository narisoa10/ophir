import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_theme_preference.dart';
import '../../domain/repositories/settings_repository.dart';

final class SharedPreferencesSettingsRepository implements SettingsRepository {
  const SharedPreferencesSettingsRepository();

  static const _themePreferenceKey = 'settings.theme_preference';

  @override
  Future<AppThemePreference> getThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_themePreferenceKey);

    return AppThemePreference.fromStorageValue(value);
  }

  @override
  Future<void> setThemePreference(AppThemePreference preference) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themePreferenceKey, preference.storageValue);
  }
}

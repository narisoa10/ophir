import '../entities/app_theme_preference.dart';

abstract interface class SettingsRepository {
  Future<AppThemePreference> getThemePreference();

  Future<void> setThemePreference(AppThemePreference preference);
}

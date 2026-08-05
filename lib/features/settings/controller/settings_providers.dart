import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/shared_preferences_settings_repository.dart';
import '../domain/entities/app_theme_preference.dart';
import '../domain/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return const SharedPreferencesSettingsRepository();
});

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppThemePreference>(
      SettingsController.new,
    );

final class SettingsController extends AsyncNotifier<AppThemePreference> {
  @override
  Future<AppThemePreference> build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.getThemePreference();
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    state = AsyncData(preference);

    final repository = ref.read(settingsRepositoryProvider);
    await repository.setThemePreference(preference);
  }
}

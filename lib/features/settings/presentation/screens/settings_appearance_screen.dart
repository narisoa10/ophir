import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../controller/settings_providers.dart';
import '../../domain/entities/app_theme_preference.dart';
import '../widgets/settings_choice_tile.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_section_card.dart';

class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedPreference =
        ref.watch(settingsControllerProvider).value ??
        AppThemePreference.system;

    return SettingsScaffold(
      title: l10n.settingsAppearanceTitle,
      children: [
        RadioGroup<AppThemePreference>(
          groupValue: selectedPreference,
          onChanged: (value) {
            if (value == null) {
              return;
            }

            ref
                .read(settingsControllerProvider.notifier)
                .setThemePreference(value);
          },
          child: SettingsSectionCard(
            title: l10n.settingsThemeSection,
            children: [
              for (final preference in AppThemePreference.values)
                SettingsChoiceTile<AppThemePreference>(
                  title: _titleFor(l10n, preference),
                  subtitle: _subtitleFor(l10n, preference),
                  value: preference,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _titleFor(AppLocalizations l10n, AppThemePreference preference) {
    return switch (preference) {
      AppThemePreference.system => l10n.settingsThemeSystemTitle,
      AppThemePreference.light => l10n.settingsThemeLightTitle,
      AppThemePreference.dark => l10n.settingsThemeDarkTitle,
    };
  }

  String _subtitleFor(AppLocalizations l10n, AppThemePreference preference) {
    return switch (preference) {
      AppThemePreference.system => l10n.settingsThemeSystemSubtitle,
      AppThemePreference.light => l10n.settingsThemeLightSubtitle,
      AppThemePreference.dark => l10n.settingsThemeDarkSubtitle,
    };
  }
}

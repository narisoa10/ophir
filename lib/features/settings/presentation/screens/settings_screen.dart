import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_failure_localization.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../auth/controller/auth_providers.dart';
import '../../../profile/controller/profile_controller.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../controller/settings_providers.dart';
import '../../domain/entities/app_theme_preference.dart';
import '../../domain/entities/settings_item.dart';
import '../../domain/entities/settings_section.dart';
import '../widgets/settings_header.dart';
import '../widgets/settings_logout_tile.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_section_view.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final themePreference =
        ref.watch(settingsControllerProvider).value ??
        AppThemePreference.system;
    final l10n = AppLocalizations.of(context);

    return profileState.when(
      loading: () => SettingsScaffold(
        title: l10n.settingsTitle,
        showAppBar: false,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => SettingsScaffold(
        title: l10n.settingsTitle,
        showAppBar: false,
        body: Center(child: Text(l10n.failureUnknown)),
      ),
      data: (result) {
        return switch (result) {
          Success<Profile>(:final value) => _buildContent(
            context,
            ref,
            l10n,
            value,
            themePreference,
          ),
          Failure<Profile>(:final failure) => SettingsScaffold(
            title: l10n.settingsTitle,
            showAppBar: false,
            body: Center(child: Text(failure.localized(l10n))),
          ),
          null => SettingsScaffold(
            title: l10n.settingsTitle,
            showAppBar: false,
            body: const Center(child: CircularProgressIndicator()),
          ),
        };
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Profile profile,
    AppThemePreference themePreference,
  ) {
    final sections = _buildSections(context, l10n, themePreference);

    return SettingsScaffold(
      title: l10n.settingsTitle,
      showAppBar: false,
      children: [
        SettingsHeader(
          profile: profile,
          fallbackName: l10n.profileNameMissing,
          onTap: () => context.push(AppRoutes.profileEdit),
        ),
        const SizedBox(height: AppSpacing.settingsSectionGap),
        for (final section in sections) ...[
          SettingsSectionView(section: section),
          const SizedBox(height: AppSpacing.settingsSectionGap),
        ],
        const SizedBox(height: AppSpacing.xs),
        SettingsLogoutTile(
          title: l10n.authSignOut,
          onTap: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ],
    );
  }

  List<SettingsSection> _buildSections(
    BuildContext context,
    AppLocalizations l10n,
    AppThemePreference themePreference,
  ) {
    return [
      SettingsSection(
        title: l10n.settingsSectionGeneral,
        items: [
          SettingsItem(
            icon: AppIcons.profileAppearance,
            title: l10n.settingsAppearanceTitle,
            subtitle: _appearanceSubtitle(l10n, themePreference),
            onTap: () => context.push(AppRoutes.settingsAppearance),
          ),
          SettingsItem(
            icon: AppIcons.actionNotifications,
            title: l10n.settingsNotificationsTitle,
            subtitle: l10n.settingsNotificationsSubtitle,
            onTap: () => _showComingSoon(context, l10n),
          ),
        ],
      ),
      SettingsSection(
        title: l10n.settingsSectionData,
        items: [
          SettingsItem(
            icon: AppIcons.navigationAccounts,
            title: l10n.accountsTitle,
            subtitle: l10n.settingsAccountsSubtitle,
            onTap: () => context.push(AppRoutes.accounts),
          ),
          SettingsItem(
            icon: AppIcons.operationCategory,
            title: l10n.categoryRulesTitle,
            subtitle: l10n.categoryRulesSettingsSubtitle,
            onTap: () => context.push(AppRoutes.categoryRules),
          ),
          SettingsItem(
            icon: AppIcons.operationCategory,
            title: l10n.settingsCategoriesTitle,
            subtitle: l10n.settingsCategoriesSubtitle,
            onTap: () => _showComingSoon(context, l10n),
          ),
          SettingsItem(
            icon: Icons.assignment_outlined,
            title: l10n.settingsBudgetPlanningTitle,
            subtitle: l10n.settingsBudgetPlanningSubtitle,
            onTap: () => context.push(AppRoutes.budgetEdit),
          ),
          SettingsItem(
            icon: AppIcons.settingsData,
            title: l10n.settingsDataTitle,
            subtitle: l10n.settingsDataSubtitle,
            onTap: () => context.push(AppRoutes.settingsData),
          ),
        ],
      ),
      SettingsSection(
        title: l10n.settingsSectionSecurity,
        items: [
          SettingsItem(
            icon: AppIcons.settingsPrivacy,
            title: l10n.settingsSecurityPrivacyTitle,
            subtitle: l10n.settingsSecurityPrivacySubtitle,
            onTap: () => _showComingSoon(context, l10n),
          ),
        ],
      ),
      SettingsSection(
        title: l10n.settingsSectionAbout,
        items: [
          SettingsItem(
            icon: AppIcons.settingsAbout,
            title: l10n.settingsAboutTitle,
            subtitle: l10n.settingsAboutSubtitle,
            onTap: () => context.push(AppRoutes.settingsAbout),
          ),
        ],
      ),
    ];
  }

  String _appearanceSubtitle(
    AppLocalizations l10n,
    AppThemePreference themePreference,
  ) {
    return switch (themePreference) {
      AppThemePreference.system => l10n.settingsAppearanceCurrentSystem,
      AppThemePreference.light => l10n.settingsAppearanceCurrentLight,
      AppThemePreference.dark => l10n.settingsAppearanceCurrentDark,
    };
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsComingSoon)));
  }
}

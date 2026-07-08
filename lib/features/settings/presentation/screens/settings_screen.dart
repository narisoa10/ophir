import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_failure_localization.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/settings_l10n.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../auth/controller/auth_providers.dart';
import '../../../profile/controller/profile_controller.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/settings_item.dart';
import '../../domain/entities/settings_section.dart';
import '../widgets/settings_header.dart';
import '../widgets/settings_logout_tile.dart';
import '../widgets/settings_section_view.dart';
import 'settings_about_screen.dart';
import 'settings_data_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      color: AppColors.background,
      child: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            l10n.failureUnknown,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        data: (result) {
          return switch (result) {
            Success<Profile>(:final value) => _buildContent(
              context,
              ref,
              l10n,
              value,
            ),
            Failure<Profile>(:final failure) => Center(
              child: Text(
                failure.localized(l10n),
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            null => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Profile profile,
  ) {
    final sections = _buildSections(context, l10n);

    return ListView(
      padding: AppSpacing.screen,
      children: [
        Text(l10n.settingsTitle, style: AppTypography.screenTitle),
        const SizedBox(height: AppSpacing.lg),
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
  ) {
    return [
      SettingsSection(
        title: l10n.settingsSectionGeneral,
        items: [
          SettingsItem(
            icon: Icons.palette_outlined,
            title: l10n.settingsAppearanceTitle,
            subtitle: l10n.settingsAppearanceSubtitle,
            onTap: () => _showComingSoon(context, l10n),
          ),
          SettingsItem(
            icon: Icons.notifications_none,
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
            icon: Icons.account_balance_wallet_outlined,
            title: l10n.accountsTitle,
            subtitle: l10n.settingsAccountsSubtitle,
            onTap: () => context.push(AppRoutes.accounts),
          ),
          SettingsItem(
            icon: Icons.category_outlined,
            title: l10n.settingsCategoriesTitle,
            subtitle: l10n.settingsCategoriesSubtitle,
            onTap: () => _showComingSoon(context, l10n),
          ),
          SettingsItem(
            icon: Icons.storage_outlined,
            title: l10n.settingsDataTitle,
            subtitle: l10n.settingsDataSubtitle,
            onTap: () => _pushSettingsScreen(
              context,
              const SettingsDataScreen(),
            ),
          ),
        ],
      ),
      SettingsSection(
        title: l10n.settingsSectionSecurity,
        items: [
          SettingsItem(
            icon: Icons.privacy_tip_outlined,
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
            icon: Icons.info_outline,
            title: l10n.settingsAboutTitle,
            subtitle: l10n.settingsAboutSubtitle,
            onTap: () => _pushSettingsScreen(
              context,
              const SettingsAboutScreen(),
            ),
          ),
        ],
      ),
    ];
  }

  void _pushSettingsScreen(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsComingSoon)));
  }
}

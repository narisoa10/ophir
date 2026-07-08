import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/settings_l10n.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/settings_item.dart';
import '../../domain/entities/settings_section.dart';
import '../widgets/settings_section_view.dart';

class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final section = SettingsSection(
      title: l10n.settingsSectionAbout,
      items: [
        SettingsItem(
          icon: Icons.info_outline,
          title: l10n.settingsAboutOphirTitle,
          subtitle: l10n.settingsAboutSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: Icons.numbers_outlined,
          title: l10n.settingsAppVersionTitle,
          subtitle: l10n.settingsAppVersionValue,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: Icons.privacy_tip_outlined,
          title: l10n.authPrivacyPolicy,
          subtitle: l10n.settingsPrivacyPolicySubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: Icons.description_outlined,
          title: l10n.settingsTermsOfServiceTitle,
          subtitle: l10n.settingsTermsSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: Icons.code_outlined,
          title: l10n.settingsOpenSourceLicensesTitle,
          subtitle: l10n.settingsOpenSourceLicensesSubtitle,
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.settingsAppName,
          ),
        ),
        SettingsItem(
          icon: Icons.mail_outline,
          title: l10n.settingsContactTitle,
          subtitle: l10n.settingsContactSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: Icons.new_releases_outlined,
          title: l10n.settingsWhatsNewTitle,
          subtitle: l10n.settingsWhatsNewSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: Text(l10n.settingsAboutTitle, style: AppTypography.bodyStrong),
      ),
      body: ListView(
        padding: AppSpacing.screen,
        children: [SettingsSectionView(section: section)],
      ),
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsComingSoon)));
  }
}

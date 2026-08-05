import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/entities/settings_item.dart';
import '../../domain/entities/settings_section.dart';
import '../widgets/settings_scaffold.dart';
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
          icon: AppIcons.settingsAbout,
          title: l10n.settingsAboutOphirTitle,
          subtitle: l10n.settingsAboutSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: AppIcons.settingsVersion,
          title: l10n.settingsAppVersionTitle,
          subtitle: l10n.settingsAppVersionValue,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: AppIcons.settingsPrivacy,
          title: l10n.authPrivacyPolicy,
          subtitle: l10n.settingsPrivacyPolicySubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: AppIcons.settingsDocument,
          title: l10n.settingsTermsOfServiceTitle,
          subtitle: l10n.settingsTermsSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: AppIcons.settingsCode,
          title: l10n.settingsOpenSourceLicensesTitle,
          subtitle: l10n.settingsOpenSourceLicensesSubtitle,
          onTap: () =>
              showLicensePage(context: context, applicationName: l10n.appTitle),
        ),
        SettingsItem(
          icon: AppIcons.actionMail,
          title: l10n.settingsContactTitle,
          subtitle: l10n.settingsContactSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: AppIcons.settingsReleaseNotes,
          title: l10n.settingsWhatsNewTitle,
          subtitle: l10n.settingsWhatsNewSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
      ],
    );

    return SettingsScaffold(
      title: l10n.settingsAboutTitle,
      children: [SettingsSectionView(section: section)],
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsComingSoon)));
  }
}

import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/entities/settings_item.dart';
import '../../domain/entities/settings_section.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_section_view.dart';

class SettingsDataScreen extends StatelessWidget {
  const SettingsDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final section = SettingsSection(
      title: l10n.settingsSectionData,
      items: [
        SettingsItem(
          icon: AppIcons.settingsStorage,
          title: l10n.settingsArchiveTitle,
          subtitle: l10n.settingsArchiveSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: AppIcons.actionUpload,
          title: l10n.settingsExportTitle,
          subtitle: l10n.settingsExportSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: AppIcons.actionDownload,
          title: l10n.settingsImportTitle,
          subtitle: l10n.settingsImportSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: AppIcons.actionBackup,
          title: l10n.settingsBackupTitle,
          subtitle: l10n.settingsBackupSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
      ],
    );

    return SettingsScaffold(
      title: l10n.settingsDataTitle,
      children: [SettingsSectionView(section: section)],
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsComingSoon)));
  }
}

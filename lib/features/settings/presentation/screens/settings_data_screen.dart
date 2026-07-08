import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/settings_l10n.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/settings_item.dart';
import '../../domain/entities/settings_section.dart';
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
          icon: Icons.inventory_2_outlined,
          title: l10n.settingsArchiveTitle,
          subtitle: l10n.settingsArchiveSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: Icons.file_upload_outlined,
          title: l10n.settingsExportTitle,
          subtitle: l10n.settingsExportSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: Icons.file_download_outlined,
          title: l10n.settingsImportTitle,
          subtitle: l10n.settingsImportSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
        SettingsItem(
          icon: Icons.backup_outlined,
          title: l10n.settingsBackupTitle,
          subtitle: l10n.settingsBackupSubtitle,
          onTap: () => _showComingSoon(context, l10n),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: Text(l10n.settingsDataTitle, style: AppTypography.bodyStrong),
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

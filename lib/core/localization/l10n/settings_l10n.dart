import '../generated/app_localizations.dart';

extension SettingsL10n on AppLocalizations {
  String get settingsAppName => 'Ophir';

  String get settingsSecurityPrivacyTitle {
    return switch (localeName) {
      'fr' => 'Securite et confidentialite',
      'ru' => 'Bezopasnost i konfidentsialnost',
      _ => 'Security & Privacy',
    };
  }

  String get settingsSecurityPrivacySubtitle {
    return switch (localeName) {
      'fr' => 'Compte, acces et donnees personnelles',
      'ru' => 'Akkount, dostup i lichnye dannye',
      _ => 'Account, access and personal data',
    };
  }

  String get settingsDataTitle {
    return switch (localeName) {
      'fr' => 'Donnees',
      'ru' => 'Dannye',
      _ => 'Data',
    };
  }

  String get settingsDataSubtitle {
    return switch (localeName) {
      'fr' => 'Archive, export, import et sauvegarde',
      'ru' => 'Arkhiv, eksport, import i rezervnye kopii',
      _ => 'Archive, export, import and backup',
    };
  }

  String get settingsAboutOphirTitle {
    return switch (localeName) {
      'fr' => 'A propos d Ophir',
      'ru' => 'O prilozhenii Ophir',
      _ => 'About Ophir',
    };
  }

  String get settingsAppVersionValue {
    return switch (localeName) {
      'fr' => 'Version 1.0.0',
      'ru' => 'Versiya 1.0.0',
      _ => 'Version 1.0.0',
    };
  }

  String get settingsTermsOfServiceTitle {
    return switch (localeName) {
      'fr' => 'Conditions de service',
      'ru' => 'Usloviya servisa',
      _ => 'Terms of Service',
    };
  }

  String get settingsContactTitle {
    return switch (localeName) {
      'fr' => 'Contact',
      'ru' => 'Kontakt',
      _ => 'Contact',
    };
  }

  String get settingsContactSubtitle {
    return switch (localeName) {
      'fr' => 'Assistance et retours',
      'ru' => 'Podderzhka i obratnaya svyaz',
      _ => 'Support and feedback',
    };
  }

  String get settingsWhatsNewTitle {
    return switch (localeName) {
      'fr' => 'Nouveautes',
      'ru' => 'Chto novogo',
      _ => 'What\'s New',
    };
  }

  String get settingsWhatsNewSubtitle {
    return switch (localeName) {
      'fr' => 'Notes de version a venir',
      'ru' => 'Primechaniya k relizu pozdnee',
      _ => 'Release notes placeholder',
    };
  }

  String get settingsArchiveTitle {
    return switch (localeName) {
      'fr' => 'Archive',
      'ru' => 'Arkhiv',
      _ => 'Archive',
    };
  }

  String get settingsArchiveSubtitle {
    return switch (localeName) {
      'fr' => 'Operations archivees',
      'ru' => 'Arkhivnye operatsii',
      _ => 'Archived operations',
    };
  }

  String get settingsExportTitle {
    return switch (localeName) {
      'fr' => 'Exporter',
      'ru' => 'Eksport',
      _ => 'Export',
    };
  }

  String get settingsExportSubtitle {
    return switch (localeName) {
      'fr' => 'Exporter vos donnees',
      'ru' => 'Eksport vashikh dannykh',
      _ => 'Export your data',
    };
  }

  String get settingsImportTitle {
    return switch (localeName) {
      'fr' => 'Importer',
      'ru' => 'Import',
      _ => 'Import',
    };
  }

  String get settingsImportSubtitle {
    return switch (localeName) {
      'fr' => 'Importer des donnees',
      'ru' => 'Import dannykh',
      _ => 'Import data',
    };
  }

  String get settingsBackupTitle {
    return switch (localeName) {
      'fr' => 'Sauvegarde',
      'ru' => 'Rezervnaya kopiya',
      _ => 'Backup',
    };
  }

  String get settingsBackupSubtitle {
    return switch (localeName) {
      'fr' => 'Sauvegardes et restauration',
      'ru' => 'Rezervnye kopii i vosstanovlenie',
      _ => 'Backups and restore',
    };
  }
}

import 'package:flutter/material.dart';

enum AppThemePreference {
  system('system', ThemeMode.system),
  light('light', ThemeMode.light),
  dark('dark', ThemeMode.dark);

  const AppThemePreference(this.storageValue, this.themeMode);

  final String storageValue;
  final ThemeMode themeMode;

  static AppThemePreference fromStorageValue(String? value) {
    for (final preference in values) {
      if (preference.storageValue == value) {
        return preference;
      }
    }

    return AppThemePreference.system;
  }
}

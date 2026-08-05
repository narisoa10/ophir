import 'settings_item.dart';

class SettingsSection {
  const SettingsSection({required this.title, required this.items});

  final String title;
  final List<SettingsItem> items;
}

import 'package:flutter/material.dart';

import '../../domain/entities/settings_section.dart';
import 'settings_menu_tile.dart';
import 'settings_section_card.dart';

class SettingsSectionView extends StatelessWidget {
  const SettingsSectionView({required this.section, super.key});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: section.title,
      children: [
        for (final item in section.items) SettingsMenuTile(item: item),
      ],
    );
  }
}

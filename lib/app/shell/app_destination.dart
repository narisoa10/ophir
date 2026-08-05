import 'package:flutter/material.dart';

import '../../core/icons/app_icons.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../router/app_routes.dart';

enum AppDestination {
  dashboard(route: AppRoutes.dashboard, icon: AppIcons.navigationHome),
  operations(route: AppRoutes.operations, icon: AppIcons.navigationOperations),
  statistics(route: AppRoutes.statistics, icon: AppIcons.navigationStatistics),
  settings(route: AppRoutes.settings, icon: AppIcons.navigationProfile);

  const AppDestination({required this.route, required this.icon});

  final String route;
  final IconData icon;

  String label(AppLocalizations l10n) {
    return switch (this) {
      AppDestination.dashboard => l10n.navigationHome,
      AppDestination.operations => l10n.navigationOperations,
      AppDestination.statistics => l10n.navigationStatistics,
      AppDestination.settings => l10n.navigationSettings,
    };
  }

  static int indexFromLocation(String location) {
    final index = values.indexWhere(
      (destination) => location.startsWith(destination.route),
    );

    return index < 0 ? 0 : index;
  }
}

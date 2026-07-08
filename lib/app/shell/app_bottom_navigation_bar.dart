import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme_v1/app_colors.dart';
import '../../core/theme_v1/app_dimensions.dart';
import '../../core/theme_v1/app_typography.dart';
import 'app_destination.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({required this.currentLocation, super.key});

  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedIndex = AppDestination.indexFromLocation(currentLocation);

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: AppDimensions.bottomNavHeight,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);

          return AppTypography.labelSm.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);

          return IconThemeData(
            color: isSelected ? AppColors.primary : AppColors.iconSecondary,
            size: AppDimensions.bottomNavIconSize,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final destination = AppDestination.values[index];

          if (destination.route != currentLocation) {
            context.go(destination.route);
          }
        },
        destinations: [
          for (final destination in AppDestination.values)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.icon),
              label: destination.label(l10n),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/services/dashboard_greeting.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.dateText,
    required this.greeting,
    this.name,
    this.avatarUrl,
    super.key,
  });

  final String dateText;
  final DashboardGreeting greeting;
  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayName = name?.trim();
    final hasName = displayName != null && displayName.isNotEmpty;

    final greetingText = switch (greeting) {
      DashboardGreeting.morning => l10n.dashboardGreetingMorning,
      DashboardGreeting.afternoon => l10n.dashboardGreetingAfternoon,
      DashboardGreeting.evening => l10n.dashboardGreetingEvening,
      DashboardGreeting.night => l10n.dashboardGreetingNight,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateText,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hasName ? '$greetingText, $displayName' : greetingText,
                style: AppTypography.screenTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(
            AppIcons.actionNotifications,
            color: AppColors.iconPrimary,
            size: AppDimensions.iconLg,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        CircleAvatar(
          radius: AppDimensions.avatarMd / 2,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl!),
          child: avatarUrl == null
              ? const Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: AppDimensions.iconMd,
                )
              : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/errors/result.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../profile/controller/profile_controller.dart';
import '../../../profile/domain/entities/profile.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final l10n = AppLocalizations.of(context);

    return profileState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _DashboardHeaderFallback(l10n: l10n),
      data: (result) {
        return switch (result) {
          Success<Profile>(:final value) => _DashboardHeaderContent(
            profile: value,
            l10n: l10n,
          ),
          Failure<Profile>() => _DashboardHeaderFallback(l10n: l10n),
          null => const Center(child: CircularProgressIndicator()),
        };
      },
    );
  }
}

class _DashboardHeaderContent extends StatelessWidget {
  const _DashboardHeaderContent({required this.profile, required this.l10n});

  final Profile profile;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final now = _nowForTimezone(profile.timezone);
    final greeting = _greetingFor(l10n, now);
    final displayName = profile.fullName?.trim();
    final hasName = displayName != null && displayName.isNotEmpty;
    final name = displayName == null || displayName.isEmpty
        ? l10n.profileNameMissing
        : displayName;
    final avatarSource = displayName == null || displayName.isEmpty
        ? profile.email
        : displayName;
    final avatarText = avatarSource.characters.first.toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: AppDimensions.avatarMd,
          backgroundColor: context.appThemeColors.primaryLight,
          backgroundImage: profile.avatarUrl == null
              ? null
              : NetworkImage(profile.avatarUrl!),
          child: profile.avatarUrl == null
              ? Text(
                  avatarText,
                  style: AppTypography.sectionTitle.copyWith(
                    color: context.appThemeColors.primary,
                  ),
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.hairline),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.screenTitle.copyWith(
                  color: hasName
                      ? context.appThemeColors.textPrimary
                      : context.appThemeColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.hairline),
              _DashboardHeaderDate(date: now),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(
          AppIcons.actionNotifications,
          color: context.appThemeColors.iconPrimary,
          size: AppDimensions.iconLg,
        ),
      ],
    );
  }

  DateTime _nowForTimezone(String timezone) {
    final value = timezone.trim();

    if (value.isEmpty || value.toLowerCase() == 'local') {
      return DateTime.now();
    }

    final upperValue = value.toUpperCase();

    if (upperValue == 'UTC' || upperValue == 'GMT') {
      return DateTime.now().toUtc();
    }

    final offset = _parseUtcOffset(upperValue);

    if (offset == null) {
      return DateTime.now();
    }

    return DateTime.now().toUtc().add(offset);
  }

  Duration? _parseUtcOffset(String value) {
    final match = RegExp(
      r'^(?:UTC|GMT)([+-])(\d{1,2})(?::?(\d{2}))?$',
    ).firstMatch(value);

    if (match == null) {
      return null;
    }

    final sign = match.group(1) == '-' ? -1 : 1;
    final hours = int.tryParse(match.group(2) ?? '');
    final minutes = int.tryParse(match.group(3) ?? '0');

    if (hours == null || minutes == null) {
      return null;
    }

    return Duration(hours: hours * sign, minutes: minutes * sign);
  }

  String _greetingFor(AppLocalizations l10n, DateTime now) {
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return l10n.dashboardHeaderGreetingMorning;
    }

    if (hour >= 12 && hour < 18) {
      return l10n.dashboardHeaderGreetingAfternoon;
    }

    if (hour >= 18 && hour < 23) {
      return l10n.dashboardHeaderGreetingEvening;
    }

    return l10n.dashboardHeaderGreetingNight;
  }
}

class _DashboardHeaderDate extends StatelessWidget {
  const _DashboardHeaderDate({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final localeName = AppLocalizations.of(context).localeName;

    return Text(
      intl.DateFormat.yMMMMEEEEd(localeName).format(date),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.caption,
    );
  }
}

class _DashboardHeaderFallback extends StatelessWidget {
  const _DashboardHeaderFallback({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.dashboardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.screenTitle.copyWith(
              color: context.appThemeColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(
          AppIcons.actionNotifications,
          color: context.appThemeColors.iconPrimary,
          size: AppDimensions.iconLg,
        ),
      ],
    );
  }
}

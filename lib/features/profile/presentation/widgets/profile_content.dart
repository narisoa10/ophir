import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../settings/presentation/widgets/profile_menu_tile.dart';
import '../../domain/entities/profile.dart';
import 'profile_avatar.dart';

class ProfileContent extends ConsumerWidget {
  const ProfileContent({required this.profile, super.key});

  final Profile profile;

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;
    final displayName = profile.fullName?.trim();
    final hasName = displayName != null && displayName.isNotEmpty;

    return ListView(
      padding: AppSpacing.screen,
      children: [
        Center(
          child: ProfileAvatar(
            profile: profile,
            radius: AppDimensions.avatarXl,
            editable: true,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Text(
            hasName ? displayName : l10n.profileNameMissing,
            style: AppTypography.headingMd.copyWith(
              color: hasName ? colors.textPrimary : colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            profile.email,
            style: AppTypography.bodyMd.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Column(
            children: [
              ProfileMenuTile(
                icon: AppIcons.profileEdit,
                title: l10n.profileEditTitle,
                subtitle: l10n.profileEditSubtitle,
                onTap: () => context.push(AppRoutes.profileEdit),
              ),
              Divider(
                height: AppDimensions.dividerThickness,
                thickness: AppDimensions.dividerThickness,
                color: colors.divider,
              ),
              ProfileMenuTile(
                icon: AppIcons.profileSecurity,
                title: l10n.profileSecurityTitle,
                subtitle: l10n.profileSecuritySubtitle,
                onTap: () {},
              ),
              Divider(
                height: AppDimensions.dividerThickness,
                thickness: AppDimensions.dividerThickness,
                color: colors.divider,
              ),
              ProfileMenuTile(
                icon: AppIcons.profileNotifications,
                title: l10n.profileNotificationsTitle,
                subtitle: l10n.profileNotificationsSubtitle,
                onTap: () {},
              ),
              Divider(
                height: AppDimensions.dividerThickness,
                thickness: AppDimensions.dividerThickness,
                color: colors.divider,
              ),
              ProfileMenuTile(
                icon: AppIcons.profileAppearance,
                title: l10n.profileAppearanceTitle,
                subtitle: l10n.profileAppearanceSubtitle,
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: ListTile(
            minTileHeight: AppDimensions.listTileLgHeight,
            contentPadding: AppSpacing.cardInsets,
            leading: Icon(
              AppIcons.profileLogout,
              color: colors.error,
              size: AppDimensions.iconLg,
            ),
            title: Text(
              l10n.authSignOut,
              style: AppTypography.titleMd.copyWith(color: colors.error),
            ),
            onTap: _signOut,
          ),
        ),
      ],
    );
  }
}

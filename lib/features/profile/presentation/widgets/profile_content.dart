import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../settings/presentation/widgets/profile_menu_tile.dart';
import '../../controller/profile_controller.dart';
import '../../domain/entities/profile.dart';

class ProfileContent extends ConsumerWidget {
  const ProfileContent({
    required this.profile,
    super.key,
  });

  final Profile profile;

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _pickAndUploadAvatar(WidgetRef ref) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );

    if (image == null) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    final extension = image.name.split('.').last.toLowerCase();
    final path = '$userId/avatar.$extension';

    await Supabase.instance.client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );

    final avatarUrl = Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(path);

    await ref.read(profileControllerProvider.notifier).updateProfile(
      profile.copyWith(
        avatarUrl: avatarUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayName = profile.fullName?.trim();
    final hasName = displayName != null && displayName.isNotEmpty;

    return ListView(
      padding: AppSpacing.screen,
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: AppDimensions.avatarXl,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: profile.avatarUrl == null
                    ? null
                    : NetworkImage(profile.avatarUrl!),
                child: profile.avatarUrl == null
                    ? Text(
                  (hasName ? displayName : profile.email)
                      .characters
                      .first
                      .toUpperCase(),
                  style: AppTypography.headingLg.copyWith(
                    color: AppColors.primary,
                  ),
                )
                    : null,
              ),
              Positioned(
                right: AppSpacing.none,
                bottom: AppSpacing.none,
                child: GestureDetector(
                  onTap: () => _pickAndUploadAvatar(ref),
                  child: Container(
                    width: AppDimensions.avatarMd,
                    height: AppDimensions.avatarMd,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.iconPrimary,
                      size: AppDimensions.iconMd,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Text(
            hasName ? displayName : l10n.profileNameMissing,
            style: AppTypography.headingMd.copyWith(
              color: hasName ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            profile.email,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Column(
            children: [
              ProfileMenuTile(
                icon: Icons.person_outline,
                title: l10n.profileEditTitle,
                subtitle: l10n.profileEditSubtitle,
                onTap: () => context.push(AppRoutes.profileEdit),
              ),
              const Divider(
                height: AppDimensions.dividerThickness,
                thickness: AppDimensions.dividerThickness,
                color: AppColors.divider,
              ),
              ProfileMenuTile(
                icon: Icons.security_outlined,
                title: l10n.profileSecurityTitle,
                subtitle: l10n.profileSecuritySubtitle,
                onTap: () {},
              ),
              const Divider(
                height: AppDimensions.dividerThickness,
                thickness: AppDimensions.dividerThickness,
                color: AppColors.divider,
              ),
              ProfileMenuTile(
                icon: Icons.notifications_none,
                title: l10n.profileNotificationsTitle,
                subtitle: l10n.profileNotificationsSubtitle,
                onTap: () {},
              ),
              const Divider(
                height: AppDimensions.dividerThickness,
                thickness: AppDimensions.dividerThickness,
                color: AppColors.divider,
              ),
              ProfileMenuTile(
                icon: Icons.palette_outlined,
                title: l10n.profileAppearanceTitle,
                subtitle: l10n.profileAppearanceSubtitle,
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          child: ListTile(
            minTileHeight: AppDimensions.listTileLgHeight,
            contentPadding: AppSpacing.cardInsets,
            leading: const Icon(
              Icons.logout,
              color: AppColors.error,
              size: AppDimensions.iconLg,
            ),
            title: Text(
              l10n.authSignOut,
              style: AppTypography.titleMd.copyWith(
                color: AppColors.error,
              ),
            ),
            onTap: _signOut,
          ),
        ),
      ],
    );
  }
}
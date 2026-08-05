import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_failure_localization.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../controller/profile_controller.dart';
import '../../domain/entities/profile.dart';

class ProfileAvatar extends ConsumerStatefulWidget {
  const ProfileAvatar({
    required this.profile,
    required this.radius,
    this.editable = false,
    super.key,
  });

  final Profile profile;
  final double radius;
  final bool editable;

  @override
  ConsumerState<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<ProfileAvatar> {
  bool _isUploading = false;

  Future<void> _showAvatarSourceSheet() async {
    if (_isUploading) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.appThemeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final colors = context.appThemeColors;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  iconColor: colors.iconSecondary,
                  textColor: colors.textPrimary,
                  leading: const Icon(AppIcons.actionCamera),
                  title: Text(l10n.profileAvatarTakePhoto),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  iconColor: colors.iconSecondary,
                  textColor: colors.textPrimary,
                  leading: const Icon(AppIcons.actionUpload),
                  title: Text(l10n.profileAvatarChooseFromGallery),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                Divider(
                  height: AppDimensions.dividerThickness,
                  thickness: AppDimensions.dividerThickness,
                  color: colors.divider,
                ),
                ListTile(
                  title: Text(
                    l10n.commonCancel,
                    style: AppTypography.bodyMd.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _uploadAvatar(source);
  }

  Future<void> _uploadAvatar(ImageSource source) async {
    setState(() {
      _isUploading = true;
    });

    final result = await ref
        .read(profileControllerProvider.notifier)
        .updateAvatar(widget.profile, source);

    if (!mounted) {
      return;
    }

    setState(() {
      _isUploading = false;
    });

    if (result case Failure<Profile>(:final failure)) {
      final l10n = AppLocalizations.of(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final avatarText = _avatarTextFor(widget.profile);
    final diameter = widget.radius * 2;

    return Semantics(
      button: widget.editable,
      label: widget.editable
          ? AppLocalizations.of(context).profileAvatarChange
          : null,
      child: GestureDetector(
        onTap: widget.editable ? _showAvatarSourceSheet : null,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CircleAvatar(
                  radius: widget.radius,
                  backgroundColor: colors.primaryLight,
                  backgroundImage: widget.profile.avatarUrl == null
                      ? null
                      : NetworkImage(widget.profile.avatarUrl!),
                  child: widget.profile.avatarUrl == null
                      ? Text(
                          avatarText,
                          style: AppTypography.headingLg.copyWith(
                            color: colors.primary,
                          ),
                        )
                      : null,
                ),
              ),
              if (_isUploading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (widget.editable)
                Positioned(
                  right: AppSpacing.none,
                  bottom: AppSpacing.none,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: AppDimensions.avatarMd,
                      height: AppDimensions.avatarMd,
                      child: _isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.sm),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              AppIcons.actionCamera,
                              size: AppDimensions.iconMd,
                              color: colors.iconPrimary,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _avatarTextFor(Profile profile) {
    final displayName = profile.fullName?.trim();
    final source = displayName == null || displayName.isEmpty
        ? profile.email
        : displayName;

    return source.characters.first.toUpperCase();
  }
}

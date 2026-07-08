import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../profile/domain/entities/profile.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({
    required this.profile,
    required this.fallbackName,
    required this.onTap,
    super.key,
  });

  final Profile profile;
  final String fallbackName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = profile.fullName?.trim();
    final hasName = displayName != null && displayName.isNotEmpty;
    final title = hasName ? displayName : fallbackName;
    final avatarText = (hasName ? displayName : profile.email).characters.first
        .toUpperCase();

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.settingsHeaderInsets,
          child: Row(
            children: [
              CircleAvatar(
                radius: AppDimensions.avatarSm,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: profile.avatarUrl == null
                    ? null
                    : NetworkImage(profile.avatarUrl!),
                child: profile.avatarUrl == null
                    ? Text(
                        avatarText,
                        style: AppTypography.sectionTitle.copyWith(
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: hasName
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.hairline),
                    Text(
                      profile.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right,
                color: AppColors.iconTertiary,
                size: AppDimensions.iconLg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme_v1/app_theme_colors.dart';
import '../theme_v1/app_dimensions.dart';
import '../theme_v1/app_radius.dart';
import '../theme_v1/app_spacing.dart';
import '../theme_v1/app_typography.dart';

enum AppFinancialListTileLevel { parent, child }

class AppFinancialListTile extends StatelessWidget {
  const AppFinancialListTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.title,
    required this.subtitle,
    required this.semanticsLabel,
    required this.onTap,
    this.level = AppFinancialListTileLevel.parent,
    this.isExpanded,
    this.trailing,
    this.padding,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String subtitle;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final AppFinancialListTileLevel level;
  final bool? isExpanded;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.isNotEmpty;
    final colors = context.appThemeColors;

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: _backgroundColor(colors),
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap,
          child: Padding(
            padding: _padding,
            child: Row(
              children: [
                Container(
                  width: _iconBoxSize,
                  height: _iconBoxSize,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Icon(icon, color: iconColor, size: _iconSize),
                ),
                const SizedBox(width: AppSpacing.inlineGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _titleStyle),
                      if (hasSubtitle) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(subtitle, style: _subtitleStyle(colors)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.inlineGap),
                trailing ??
                    Icon(
                      _trailingIcon,
                      color: colors.iconSecondary,
                      size: _trailingIconSize,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _backgroundColor(AppThemeColors colors) {
    return switch (level) {
      AppFinancialListTileLevel.parent => colors.background,
      AppFinancialListTileLevel.child => Colors.transparent,
    };
  }

  EdgeInsets get _padding {
    final customPadding = padding;
    if (customPadding != null) {
      return customPadding;
    }

    return switch (level) {
      AppFinancialListTileLevel.parent => AppSpacing.listTileInsets,
      AppFinancialListTileLevel.child => AppSpacing.compactListTileInsets,
    };
  }

  double get _iconBoxSize {
    return switch (level) {
      AppFinancialListTileLevel.parent =>
        AppDimensions.financialStateHeaderIconBox,
      AppFinancialListTileLevel.child => AppDimensions.avatarSm,
    };
  }

  double get _iconSize {
    return switch (level) {
      AppFinancialListTileLevel.parent => AppDimensions.iconMd,
      AppFinancialListTileLevel.child => AppDimensions.iconSm,
    };
  }

  TextStyle get _titleStyle {
    return switch (level) {
      AppFinancialListTileLevel.parent => AppTypography.bodyStrong,
      AppFinancialListTileLevel.child => AppTypography.body,
    };
  }

  TextStyle _subtitleStyle(AppThemeColors colors) {
    return switch (level) {
      AppFinancialListTileLevel.parent => AppTypography.caption.copyWith(
        color: colors.textSecondary,
      ),
      AppFinancialListTileLevel.child => AppTypography.caption.copyWith(
        color: colors.textTertiary,
      ),
    };
  }

  IconData get _trailingIcon {
    return switch (isExpanded) {
      true => AppIcons.actionChevronUp,
      false => AppIcons.actionChevronDown,
      null => AppIcons.actionChevronRight,
    };
  }

  double get _trailingIconSize {
    return switch (level) {
      AppFinancialListTileLevel.parent => AppDimensions.iconMd,
      AppFinancialListTileLevel.child => AppDimensions.iconSm,
    };
  }
}

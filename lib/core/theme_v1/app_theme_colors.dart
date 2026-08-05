import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
final class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.primary,
    required this.primaryLight,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textInverse,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconTertiary,
    required this.border,
    required this.divider,
    required this.progressTrack,
    required this.shadow,
    required this.error,
    required this.success,
    required this.warning,
    required this.surfaceGreen,
    required this.surfaceRed,
    required this.surfaceBlue,
    required this.surfacePurple,
    required this.chartGreen,
    required this.chartRed,
    required this.chartBlue,
    required this.chartPurple,
  });

  final Color primary;
  final Color primaryLight;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textInverse;
  final Color iconPrimary;
  final Color iconSecondary;
  final Color iconTertiary;
  final Color border;
  final Color divider;
  final Color progressTrack;
  final Color shadow;
  final Color error;
  final Color success;
  final Color warning;
  final Color surfaceGreen;
  final Color surfaceRed;
  final Color surfaceBlue;
  final Color surfacePurple;
  final Color chartGreen;
  final Color chartRed;
  final Color chartBlue;
  final Color chartPurple;

  static const light = AppThemeColors(
    primary: AppColors.primary,
    primaryLight: AppColors.primaryLight,
    background: AppColors.background,
    surface: AppColors.surface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    textDisabled: AppColors.textDisabled,
    textInverse: AppColors.textInverse,
    iconPrimary: AppColors.iconPrimary,
    iconSecondary: AppColors.iconSecondary,
    iconTertiary: AppColors.iconTertiary,
    border: AppColors.border,
    divider: AppColors.divider,
    progressTrack: AppColors.progressTrack,
    shadow: AppColors.shadow,
    error: AppColors.error,
    success: AppColors.success,
    warning: Color(0xFFF59E0B),
    surfaceGreen: AppColors.surfaceGreen,
    surfaceRed: AppColors.surfaceRed,
    surfaceBlue: AppColors.surfaceBlue,
    surfacePurple: AppColors.surfacePurple,
    chartGreen: AppColors.chartGreen,
    chartRed: AppColors.chartRed,
    chartBlue: AppColors.chartBlue,
    chartPurple: AppColors.chartPurple,
  );

  static const dark = AppThemeColors(
    primary: AppColors.primary,
    primaryLight: Color(0xFF3A2418),
    background: Color(0xFF101114),
    surface: Color(0xFF1A1C20),
    textPrimary: Color(0xFFF4F5F7),
    textSecondary: Color(0xFFB0B6C0),
    textTertiary: Color(0xFF858C98),
    textDisabled: Color(0xFF515865),
    textInverse: AppColors.textInverse,
    iconPrimary: Color(0xFFF4F5F7),
    iconSecondary: Color(0xFFB0B6C0),
    iconTertiary: Color(0xFF858C98),
    border: Color(0xFF2B3038),
    divider: Color(0xFF2B3038),
    progressTrack: Color(0xFF2B3038),
    shadow: Color(0x66000000),
    error: AppColors.error,
    success: AppColors.success,
    warning: Color(0xFFF59E0B),
    surfaceGreen: Color(0xFF123021),
    surfaceRed: Color(0xFF351A1A),
    surfaceBlue: Color(0xFF14283F),
    surfacePurple: Color(0xFF2A2140),
    chartGreen: Color(0xFF22C55E),
    chartRed: Color(0xFFEF4444),
    chartBlue: Color(0xFF60A5FA),
    chartPurple: Color(0xFFA78BFA),
  );

  @override
  AppThemeColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? textInverse,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? iconTertiary,
    Color? border,
    Color? divider,
    Color? progressTrack,
    Color? shadow,
    Color? error,
    Color? success,
    Color? warning,
    Color? surfaceGreen,
    Color? surfaceRed,
    Color? surfaceBlue,
    Color? surfacePurple,
    Color? chartGreen,
    Color? chartRed,
    Color? chartBlue,
    Color? chartPurple,
  }) {
    return AppThemeColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      textInverse: textInverse ?? this.textInverse,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      iconTertiary: iconTertiary ?? this.iconTertiary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      progressTrack: progressTrack ?? this.progressTrack,
      shadow: shadow ?? this.shadow,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      surfaceGreen: surfaceGreen ?? this.surfaceGreen,
      surfaceRed: surfaceRed ?? this.surfaceRed,
      surfaceBlue: surfaceBlue ?? this.surfaceBlue,
      surfacePurple: surfacePurple ?? this.surfacePurple,
      chartGreen: chartGreen ?? this.chartGreen,
      chartRed: chartRed ?? this.chartRed,
      chartBlue: chartBlue ?? this.chartBlue,
      chartPurple: chartPurple ?? this.chartPurple,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) {
      return this;
    }

    return AppThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      iconTertiary: Color.lerp(iconTertiary, other.iconTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      surfaceGreen: Color.lerp(surfaceGreen, other.surfaceGreen, t)!,
      surfaceRed: Color.lerp(surfaceRed, other.surfaceRed, t)!,
      surfaceBlue: Color.lerp(surfaceBlue, other.surfaceBlue, t)!,
      surfacePurple: Color.lerp(surfacePurple, other.surfacePurple, t)!,
      chartGreen: Color.lerp(chartGreen, other.chartGreen, t)!,
      chartRed: Color.lerp(chartRed, other.chartRed, t)!,
      chartBlue: Color.lerp(chartBlue, other.chartBlue, t)!,
      chartPurple: Color.lerp(chartPurple, other.chartPurple, t)!,
    );
  }
}

extension AppThemeColorsContext on BuildContext {
  AppThemeColors get appThemeColors {
    return Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;
  }
}

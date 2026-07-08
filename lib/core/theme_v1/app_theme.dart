import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: _lightColorScheme,
      textTheme: AppTypography.textTheme,
      appBarTheme: _appBarTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      textButtonTheme: _textButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      navigationBarTheme: _navigationBarTheme,
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.textInverse,
    secondary: AppColors.success,
    onSecondary: AppColors.textInverse,
    error: AppColors.error,
    onError: AppColors.textInverse,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
  );

  static final AppBarTheme _appBarTheme = AppBarTheme(
    elevation: AppSpacing.none,
    scrolledUnderElevation: AppSpacing.none,
    centerTitle: true,
    toolbarHeight: AppDimensions.appBarHeight,
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.textPrimary,
    iconTheme: const IconThemeData(
      color: AppColors.iconPrimary,
      size: AppDimensions.iconLg,
    ),
    titleTextStyle: AppTypography.titleLg,
  );

  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppSpacing.none,
          minimumSize: const Size(
            AppDimensions.buttonMinWidth,
            AppDimensions.buttonMdHeight,
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          disabledBackgroundColor: AppColors.primaryLight,
          disabledForegroundColor: AppColors.textDisabled,
          textStyle: AppTypography.buttonMd,
          padding: AppSpacing.buttonInsets,
          shape: AppRadius.buttonShape,
        ),
      );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      disabledForegroundColor: AppColors.textDisabled,
      textStyle: AppTypography.buttonMd,
      padding: AppSpacing.buttonInsets,
      shape: AppRadius.buttonShape,
    ),
  );

  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.textTertiary),
        labelStyle: AppTypography.bodyMd.copyWith(
          color: AppColors.textSecondary,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(color: AppColors.primary),
        ),
      );

  static final NavigationBarThemeData _navigationBarTheme =
      NavigationBarThemeData(
        height: AppDimensions.bottomNavHeight,
        elevation: AppSpacing.none,
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
      );
}
